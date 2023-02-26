//
//  AppDelegate.swift
//  remindful
//
//  Created by Brett Gutstein on 1/17/23.
//

import Cocoa
import SwiftUI
import Carbon.HIToolbox

let REMINDER_INTERVAL_SECONDS = 30 * 60 // TODO user configurable

class KeyPanel : NSPanel {
    public override var acceptsFirstResponder: Bool {
        get { return true }
    }
    public override var canBecomeKey: Bool {
        get { return true }
    }
    public override var canBecomeMain: Bool {
        get { return true }
    }

    public var keyPressCallback: (() -> Void)? = nil

    public override func keyDown(with event: NSEvent) {
        if (keyPressCallback != nil) {
            keyPressCallback!()
        }
    }
}

// needed so click even when the panel is non-key will trigger an event
class FirstMouseNSView : NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

struct RepresentableFirstMouseNSView : NSViewRepresentable {
    func makeNSView(context: NSViewRepresentableContext<RepresentableFirstMouseNSView>) -> FirstMouseNSView {
        return FirstMouseNSView()
    }

    func updateNSView(_ nsView: FirstMouseNSView, context: NSViewRepresentableContext<RepresentableFirstMouseNSView>) {
        nsView.setNeedsDisplay(nsView.bounds)
    }

    typealias NSViewType = FirstMouseNSView
}

// TODO record and display number of reminders overall and for the session (allow reset for overall)
struct PanelView: View {
    var body: some View {
        Text("take a break\n\npress any key or click to exit").frame(maxWidth: .infinity, maxHeight: .infinity).multilineTextAlignment(.center).overlay(RepresentableFirstMouseNSView())
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // state
    var reminderWindow: KeyPanel!
    var statusItem: NSStatusItem! // space in sattus bar
    var statusMenu: NSMenu! // dropdown menu
    var menuButton: NSStatusBarButton! // button in space in status bar
    var countdownMenuItem: NSMenuItem! // menu item that shows countdown

    var secondsTimer: Timer!
    var secondsUntilReminder = -1 // -1 when disabled, 0 when reminder shown, positive when counting down
    var savedSecondsUntilReminder = -1 // to stop countdowns while the machine is sleeping
    var canUserCloseReminder = false // flag to delay reminder close until after it fades in


    // helpers

    func areRemindersEnabled() -> Bool {
        return secondsUntilReminder != -1
    }

    func isReminderShowing() -> Bool {
        return secondsUntilReminder == 0
    }

    func scheduleShowReminder() {
        secondsUntilReminder = REMINDER_INTERVAL_SECONDS
    }

    @objc func showReminder() {
        print("showReminder \(Date())")

        reminderWindow.alphaValue = 0
        reminderWindow.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 0.99
            reminderWindow.animator().alphaValue = 1
        }, completionHandler: {
            self.canUserCloseReminder = true
        })
    }

    @objc func hideReminder() {
        print("hideReminder \(Date())")

        reminderWindow.makeKeyAndOrderFront(nil) // needed for this to work correctly for some reason
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 0.99
            reminderWindow.animator().alphaValue = 0
        }, completionHandler: {
            self.reminderWindow.close()
        })
    }

    @objc func enableReminders() {
        print("enableReminders \(Date())")
        scheduleShowReminder()
        menuButton.image = NSImage.init(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: nil ) // TODO fix
    }

    @objc func disableReminders() {
        print("disableReminders \(Date())")

        if (isReminderShowing()) {
            hideReminder()
        }
        secondsUntilReminder = -1

        countdownMenuItem.title = "Reminders disabled"
        menuButton.image = NSImage.init(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil ) // TODO fix
    }

    @objc func toggleReminders() {
        print("toggleReminders \(Date())")
        areRemindersEnabled() ? disableReminders() : enableReminders()
    }

    // event handling

    @objc func secondsTick() {
        if (secondsUntilReminder > 0) {
            secondsUntilReminder -= 1
            countdownMenuItem.title = "Reminder in " + String(secondsUntilReminder) // TODO DD:HH:MM
            if (secondsUntilReminder == 0) {
                showReminder()
            }
        }
    }

    @objc func wakeFromSleep(note: NSNotification) {
        print("wakeFromSleep \(Date())")

        secondsUntilReminder = savedSecondsUntilReminder

        if (isReminderShowing()) {
            hideReminder()
        }

        if (areRemindersEnabled()) {
            if (true) { // TODO if ResetOnWake setting true
                scheduleShowReminder()
            }
        } else {
            if (true) { // TODO if EnableOnWake setting true
                enableReminders()
            }
        }
    }

    @objc func goToSleep(note: NSNotification) {
        print("goToSleep \(Date())")

        savedSecondsUntilReminder = secondsUntilReminder
        secondsUntilReminder = -1
    }

    @objc func userClosedReminder() {
        print("userClosedReminder \(Date())")

        if (canUserCloseReminder) {
            canUserCloseReminder = false
            hideReminder()
            scheduleShowReminder()
        }
    }

    // UI

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusMenu = NSMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        menuButton = statusItem.button!
        menuButton.action = #selector(statusBarButtonClick(_:))
        menuButton.sendAction(on: [.leftMouseUp, .rightMouseUp])

        countdownMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenu.addItem(countdownMenuItem)
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel(_:)), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: ""))

        reminderWindow = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: NSScreen.main!.frame.width, height: NSScreen.main!.frame.height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        reminderWindow.level = .mainMenu
        reminderWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        reminderWindow.keyPressCallback = userClosedReminder
        reminderWindow.contentView? = NSHostingView(rootView: PanelView().contentShape(Rectangle()).onTapGesture {
            self.userClosedReminder()
        })

        print("inited \(Date())")

        // TODO doesn't tick while the menu is open
        secondsTimer = Timer.scheduledTimer(timeInterval: 1,
                                            target: self,
                                            selector: #selector(secondsTick),
                                            userInfo: nil,
                                            repeats: true)

        NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(wakeFromSleep(note:)),
                name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(goToSleep(note:)),
                name: NSWorkspace.willSleepNotification, object: nil)

        enableReminders()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    @objc func statusBarButtonClick(_ sender: Any) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.leftMouseUp {
            toggleReminders()
        } else if event.type == NSEvent.EventType.rightMouseUp {
            statusItem.popUpMenu(statusMenu)
        }
    }

    @objc func quit(_ sender: Any) {
        NSApp.terminate(self)
    }

    // TODO fix
    @objc func showAboutPanel(_ sender: Any) {
        let github = NSMutableAttributedString(string: "https://github.com/brettferdosi/remindful")
        github.addAttribute(.link, value: "https://github.com/brettferdosi/remindful",
                            range: NSRange(location: 0, length: github.length))

        let website = NSMutableAttributedString(string: "https://brett.gutste.in")
        website.addAttribute(.link, value: "https://brett.gutste.in",
                             range: NSRange(location: 0, length: website.length))

        let credits = NSMutableAttributedString(string:"")
        credits.append(github)
        credits.append(NSMutableAttributedString(string: "\n"))
        credits.append(website)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        credits.addAttribute(.paragraphStyle, value: paragraphStyle,
                             range: NSRange(location: 0, length: credits.length))

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [ .credits : credits ])
    }

}

