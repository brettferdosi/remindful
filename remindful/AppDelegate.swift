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
    @AppStorage("remindersSinceReset") var remindersSinceReset: Int = 0 // total number of reminders
    @AppStorage("remindersSinceSleep") var remindersSinceSleep: Int = 0 // number of reminders since machine last slept
    @AppStorage("reminderIntervalSeconds") var reminderIntervalSeconds: Int = 30 * 60 // length of interval between reminders in seconds
    @AppStorage("enableRemindersOnWake") var enableRemindersOnWake: Bool = true // if reminders are disabled on wake, enable them
    @AppStorage("resetTimerOnWake") var resetTimerOnWake: Bool = true // if reminders are enabled on wake, reset the timer

    @Published var userInputtedReminderIntervalSeconds: Int = 0 // for user setting of interval
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // state

    var reminderWindows: [ReminderPanel]! = [] // windows for reminder
    var settingsWindow: SettingsWindow! // window for settings
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

    // helpers

    func enableTimer() {
        if (secondsTimer == nil) {
            secondsTimer = Timer.scheduledTimer(timeInterval: 1,
                                                target: self,
                                                selector: #selector(secondsTick),
                                                userInfo: nil,
                                                repeats: true)
            RunLoop.current.add(secondsTimer, forMode: RunLoop.Mode.common)
        }
    }

    func disableTimer() {
        if (secondsTimer != nil) {
            secondsTimer.invalidate()
            secondsTimer = nil
        }
    }

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

        let screens = NSScreen.screens
        reminderWindows = screens.map({(screen: NSScreen) -> ReminderPanel in ReminderPanel(state: uiVisibleState, callback: userClosedReminder, displayScreen: screen)})
        for reminderWindow in reminderWindows {
            reminderWindow.displayReminder()
        }
    }

    @objc func hideReminder() {
        print("hideReminder \(Date())")

        for reminderWindow in reminderWindows {
            reminderWindow.closeReminder()
        }
    }

    @objc func enableReminders() {
        print("enableReminders \(Date())")
        enableTimer()
        scheduleShowReminder()
        menuButton.image = NSImage(named: "open")
    }

    @objc func disableReminders() {
        print("disableReminders \(Date())")

        if (isReminderShowing()) {
            hideReminder()
        }
        secondsUntilReminder = -1
        disableTimer()

        countdownMenuItem.title = "Reminders disabled"
        menuButton.image = NSImage(named: "closed")
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

        enableTimer()

        if (areRemindersEnabled()) {
            if (uiVisibleState.resetTimerOnWake) {
                scheduleShowReminder()
            }
        } else {
            if (uiVisibleState.enableRemindersOnWake) {
                enableReminders()
            }
        }
    }

    @objc func goToSleep(note: NSNotification) {
        print("goToSleep \(Date())")

        savedSecondsUntilReminder = secondsUntilReminder
        secondsUntilReminder = -1
        disableTimer()
    }

    @objc func userClosedReminder() {
        print("userClosedReminder \(Date())")

        hideReminder()
        scheduleShowReminder()
    }

    // menu bar UI

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusMenu = NSMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        menuButton = statusItem.button!
        menuButton.action = #selector(statusBarButtonClick(_:))
        menuButton.sendAction(on: [.leftMouseUp, .rightMouseUp])

        settingsWindow = SettingsWindow(state: uiVisibleState)

        countdownMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenu.addItem(countdownMenuItem)
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel(_:)), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettingsWindow(_:)), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: ""))

        print("inited \(Date())")

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

    @objc func showSettingsWindow(_ sender: Any) {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
    }
}

class SettingsWindow: NSWindow, NSWindowDelegate {
    @ObservedObject var state: UIVisisbleState

    private let width: CGFloat = 450
    private let height: CGFloat = 250
    private let settingsView: SettingsView

    // SwiftUI to render settings
    struct SettingsView: View {
        @ObservedObject var state: UIVisisbleState

        init(state: UIVisisbleState) {
            self.state = state
            state.userInputtedReminderIntervalSeconds = state.reminderIntervalSeconds
        }

        var body: some View {

            VStack(alignment: .leading) {
                HStack {
                    Text("Number of seconds between reminders")
                    TextField("", value: $state.userInputtedReminderIntervalSeconds, formatter: NumberFormatter())
                        // don't allow the inputted interval to be non-positive
                        .onChange(of: state.userInputtedReminderIntervalSeconds)
                        { [oldValue = state.userInputtedReminderIntervalSeconds] newValue  in
                            if (newValue <= 0) {
                                self.state.userInputtedReminderIntervalSeconds = oldValue
                            }
                        }
                }
                HStack {
                    Text("Reminder messsage")
                    TextField("", text: $state.reminderMessage)
                }
                HStack {
                    Text("Enable reminders on wake")
                    Toggle("", isOn: $state.enableRemindersOnWake).labelsHidden()
                }
                HStack {
                    Text("Reset reminder timer on wake")
                    Toggle("", isOn: $state.resetTimerOnWake).labelsHidden()
                }
                Text("Reminders since computer last woke from sleep: \(state.remindersSinceSleep)")
                HStack {
                    Text("Reminders since last reset: \(state.remindersSinceReset)")
                    Button("Reset", action: { state.remindersSinceReset = 0 })
                }


            }.padding(30)
        }
    }

    // when the window is about to close and the user changed the interval start the timer using the new interval
    func windowWillClose(_ notification: Notification) {
        if state.userInputtedReminderIntervalSeconds != state.reminderIntervalSeconds && state.userInputtedReminderIntervalSeconds > 0 {
            print("user changed reminder interval to \(state.userInputtedReminderIntervalSeconds) \(Date())")
            state.reminderIntervalSeconds = state.userInputtedReminderIntervalSeconds
            let delegate = (NSApplication.shared.delegate as! AppDelegate)
            if (delegate.areRemindersEnabled())  {
                delegate.scheduleShowReminder()
            }
        }
    }

    init(state: UIVisisbleState) {
        self.state = state
        self.settingsView = SettingsView(state: state)
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [ .titled, .closable ], backing: .buffered, defer: false)
        level = .floating
        title = "Remindful Settings"
        isReleasedWhenClosed = false
        contentView? = NSHostingView(rootView: self.settingsView.frame(width: width, height: height))
        self.delegate = self
        self.center()
    }
}

// reminder panel that will go over every other window and remain the key window while it is open;
// calls the passed-in callback on mouse click or any keypress
class ReminderPanel: NSPanel, NSWindowDelegate {
    @ObservedObject var state: UIVisisbleState
    var callback: (() -> Void) // to be called when reminder closes
    private var shouldRemainKey = false // if something else becomes key, should we take it back?
    private var canCloseReminder = false // has the reminder been animated in long enough to close it?
    private var displayScreen: NSScreen! // screen to display on

    init(state: UIVisisbleState, callback: @escaping (() -> Void), displayScreen: NSScreen) {
        self.state = state
        self.callback = callback
        self.displayScreen = displayScreen

        super.init(contentRect: NSRect(x: displayScreen.frame.minX, y: displayScreen.frame.minY, width: displayScreen.frame.width, height: displayScreen.frame.height), // make fullscreen
                   styleMask: [ .borderless, // don't display peripheral elements
                                .nonactivatingPanel ], // fixes some UI flicker when changing spaces
                   backing: .buffered, // render drawing into a display buffer
                   defer: false) // create window device immediately
        level = .mainMenu // display on top of other windows
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // show in all spaces and over fullscreen apps
        backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 0.85) // translucent
        contentView? = NSHostingView(rootView: ReminderPanelView(state: state).contentShape(Rectangle())) // contentShape needed to make clicking work everywhere

        delegate = self
    }

    // SwiftUI to render text
    struct ReminderPanelView: View {
        @ObservedObject var state: UIVisisbleState

        var body: some View {
            Text("\(state.reminderMessage)\n\n\(state.remindersSinceSleep) reminders since last sleep\n\(state.remindersSinceReset) reminders since last reset\n\npress any key or click to exit").font(.system(.largeTitle, design: .monospaced)).foregroundColor(.white).multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // panels can't be these things by default, need to override them
    public override var acceptsFirstResponder: Bool {
        get { return true }
    }
    public override var canBecomeKey: Bool {
        get { return true }
    }
    public override var canBecomeMain: Bool {
        get { return true }
    }

    public override func keyDown(with event: NSEvent) {
        if (self.canCloseReminder) {
            callback()
        }
    }

    public override func mouseDown(with event: NSEvent) {
        if (self.canCloseReminder) {
            callback()
        }
    }

    func displayReminder() {
        shouldRemainKey = true

        alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 0.99
            animator().alphaValue = 1
        }, completionHandler: { self.canCloseReminder = true })
    }

    func closeReminder() {
        shouldRemainKey = false
        canCloseReminder = false

        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 0.99
            animator().alphaValue = 0
        }, completionHandler: {
            NSApp.hide(nil) // restore focus to previous app
            self.close()
        })
    }

    func windowDidResignKey(_ notification: Notification) {
        if (shouldRemainKey) {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        }
    }
}
