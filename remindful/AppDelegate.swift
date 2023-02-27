//
//  AppDelegate.swift
//  remindful
//
//  Created by Brett Gutstein on 1/17/23.
//

import Cocoa
import SwiftUI
import Carbon.HIToolbox

class UIVisisbleState: ObservableObject {
    @AppStorage("reminderMessage") var reminderMessage: String = "remindful"
    @AppStorage("remindersSinceReset") var remindersSinceReset: Int = 0 // TODO implement reset
    @AppStorage("remindersSinceSleep") var remindersSinceSleep: Int = 0
    @AppStorage("reminderIntervalSeconds") var reminderIntervalSeconds: Int = 30 * 60 // length of interval between reminders in seconds
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // state

    var reminderWindow: ReminderPanel! // window for reminder
    var statusItem: NSStatusItem! // space in sattus bar
    var statusMenu: NSMenu! // dropdown menu
    var menuButton: NSStatusBarButton! // button in space in status bar
    var countdownMenuItem: NSMenuItem! // menu item that shows countdown
    let hmsFormatter = { // format integer seconds to hh:mm:ss
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter
    }()

    let uiVisibleState = UIVisisbleState() // state accessible by user interface

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
        secondsUntilReminder = uiVisibleState.reminderIntervalSeconds
    }

    @objc func showReminder() {
        print("showReminder \(Date())")

        uiVisibleState.remindersSinceReset += 1
        uiVisibleState.remindersSinceSleep += 1

        reminderWindow.displayReminder(callback: {
            self.canUserCloseReminder = true
        })
    }

    @objc func hideReminder() {
        print("hideReminder \(Date())")

        reminderWindow.closeReminder()
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
            countdownMenuItem.title = "Reminder in " + hmsFormatter.string(from: TimeInterval(secondsUntilReminder))!
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

        uiVisibleState.remindersSinceSleep = 0

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

    // menu bar UI

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

        reminderWindow = ReminderPanel(state: uiVisibleState, callback: userClosedReminder)

        print("inited \(Date())")

        // TODO may be nice to invalidate the timer when reminders are disabled or machine is asleep
        secondsTimer = Timer.scheduledTimer(timeInterval: 1,
                                            target: self,
                                            selector: #selector(secondsTick),
                                            userInfo: nil,
                                            repeats: true)
        RunLoop.current.add(secondsTimer, forMode: RunLoop.Mode.common)

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

    // TODO fix logo
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

