//
//  ReminderUI.swift
//  remindful
//
//  Created by Brett Gutstein on 2/27/23.
//

import SwiftUI

// SwiftUI to render text
struct ReminderPanelView: View {
    @ObservedObject var state: UIVisisbleState

    var body: some View {
        Text("\(state.reminderMessage)\n\n\(state.remindersSinceSleep) reminders since last sleep\n\(state.remindersSinceReset) reminders since last reset\n\npress any key or click to exit").font(.system(.largeTitle, design: .monospaced)).multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// reminder panel that will go over every other window and remain the key window while it is open;
// calls the passed-in callback on mouse click or any keypress
class ReminderPanel: NSPanel, NSWindowDelegate {
    @ObservedObject var state: UIVisisbleState
    var callback: (() -> Void)

    private var shouldRemainKey = false

    init(state: UIVisisbleState, callback: @escaping (() -> Void)) {
        self.state = state
        self.callback = callback

        super.init(contentRect: NSRect(x: 0, y: 0, width: NSScreen.main!.frame.width, height: NSScreen.main!.frame.height), // make fullscreen
                   styleMask: [ .borderless, // don't display peripheral elements
                                .nonactivatingPanel ], // fixes some UI flicker when changing spaces
                   backing: .buffered, // render drawing into a display buffer
                   defer: false) // create window device immediately
        level = .mainMenu // display on top of other windows
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // show in all spaces and over fullscreen apps
        backgroundColor = backgroundColor.withAlphaComponent(0.75) // translucent
        contentView? = NSHostingView(rootView: ReminderPanelView(state: state).contentShape(Rectangle())) // contentShape needed to make clicking work everywhere

        delegate = self
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
           callback()
    }

    public override func mouseDown(with event: NSEvent) {
        callback()
    }

    func displayReminder(callback: @escaping (() -> Void)) {
        shouldRemainKey = true

        alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 0.99
            animator().alphaValue = 1
        }, completionHandler: callback)
    }

    func closeReminder() {
        shouldRemainKey = false

        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 0.99
            animator().alphaValue = 0
        }, completionHandler: {
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
