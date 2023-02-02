//
//  AppDelegate.swift
//  remindful
//
//  Created by Brett Gutstein on 1/17/23.
//

import Cocoa
import SwiftUI
import Carbon.HIToolbox

let REMINDER_INTERVAL_SECONDS : Double = 30 * 60

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

    public var escKeyCallback: (() -> Void)? = nil

    public override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            if (escKeyCallback != nil) {
                escKeyCallback!()
            }
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

struct PanelView: View {
    var body: some View {
        Text("take a break\n\npress esc or click anywhere to exit").frame(maxWidth: .infinity, maxHeight: .infinity).multilineTextAlignment(.center).overlay(RepresentableFirstMouseNSView())
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // state

    var reminderWindow: KeyPanel!
    var reminderTimer: Timer? // nil when reminders disabled, valid when reminder scheduled, invalid after reminder fires

    var statusItem: NSStatusItem! // space in sattus bar
    var statusMenu: NSMenu! // dropdown menu
    var menuButton: NSStatusBarButton! // button in space in status bar


    // helpers

    func areRemindersEnabled() -> Bool {
        return reminderTimer != nil
    }

    func hasReminderBeenShown() -> Bool {
        return reminderTimer != nil && !reminderTimer!.isValid
    }

    func scheduleShowReminder() {
        if (reminderTimer != nil) {
            reminderTimer!.invalidate()
        }
        reminderTimer = Timer.scheduledTimer(timeInterval: REMINDER_INTERVAL_SECONDS,
                                             target: self,
                                             selector: #selector(showReminder),
                                             userInfo: nil,
                                             repeats: false)
    }

    @objc func showReminder() {
        print("showReminder \(Date())")

        if (!hasReminderBeenShown()) {
            reminderWindow.alphaValue = 0
            reminderWindow.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup({ (context) -> Void in
                context.duration = 0.99
                reminderWindow.animator().alphaValue = 1
            }, completionHandler: nil)
        }
    }

    @objc func hideReminder() {
        print("hideReminder \(Date())")

        if (hasReminderBeenShown()) {
            reminderWindow.makeKeyAndOrderFront(nil) // needed for this to work correctly for some reason
            NSAnimationContext.runAnimationGroup({ (context) -> Void in
                context.duration = 0.99
                reminderWindow.animator().alphaValue = 0
            }, completionHandler: {
                self.reminderWindow.close()
            })
        }
    }

    @objc func enableReminders() {
        print("enableReminders \(Date())")
        scheduleShowReminder()
        menuButton.image = NSImage.init(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: nil ) // TODO fix
    }

    @objc func disableReminders() {
        print("disableReminders \(Date())")

        hideReminder()
        if (reminderTimer != nil) {
            reminderTimer!.invalidate()
            reminderTimer = nil
        }

        menuButton.image = NSImage.init(systemSymbolName: "ellipsis.circle", accessibilityDescription: nil ) // TODO fix
    }

    @objc func toggleReminders() {
        print("toggleReminders \(Date())")
        areRemindersEnabled() ? disableReminders() : enableReminders()
    }

    // event handling

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusMenu = NSMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        menuButton = statusItem.button!
        menuButton.action = #selector(statusBarButtonClick(_:))
        menuButton.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel(_:)), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: ""))

        reminderWindow = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: NSScreen.main!.frame.width, height: NSScreen.main!.frame.height), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        reminderWindow.level = .mainMenu
        reminderWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        reminderWindow.escKeyCallback = userClosedReminder
        reminderWindow.contentView? = NSHostingView(rootView: PanelView().contentShape(Rectangle()).onTapGesture {
            self.userClosedReminder()
        })

        print("inited \(Date())")
        // TODO make a toggleable feature
        NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(wakeFromSleep(note:)),
                name: NSWorkspace.didWakeNotification, object: nil)
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

    @objc func wakeFromSleep(note: NSNotification) {
        print("wakeFromSleep \(Date())")
        if (!areRemindersEnabled()) {
            enableReminders()
        }
    }

    @objc func userClosedReminder() {
        hideReminder()
        scheduleShowReminder()
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

