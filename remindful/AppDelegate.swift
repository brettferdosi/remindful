//
//  AppDelegate.swift
//  remindful
//
//  Created by Brett Gutstein on 1/17/23.
//

import Cocoa
import SwiftUI
import Carbon.HIToolbox

//let REMINDER_LENGTH_SECONDS : Double = 5
//let REMINDER_INTERVAL_SECONDS : Double = 5

let REMINDER_LENGTH_SECONDS : Double = 30
let REMINDER_INTERVAL_SECONDS : Double = 60 * 30

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

struct PanelView: View {
    var body: some View {
        Text("take a break").frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var reminderWindow: KeyPanel!
    var reminderTimer: Timer?

    var statusItem: NSStatusItem!
    var statusMenu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusMenu = NSMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let menuButton = statusItem.button else {
            print("couldn't get status item button")
            NSApp.terminate(self)
            return
        }

        menuButton.image = NSImage.init(systemSymbolName: "pencil", accessibilityDescription: nil ) // TODO fix
        menuButton.action = #selector(statusBarButtonClick(_:))
        menuButton.sendAction(on: [.leftMouseUp, .rightMouseUp])

        statusMenu.addItem(NSMenuItem(title: "About", action: #selector(showAboutPanel(_:)), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quit(_:)), keyEquivalent: ""))
        
        reminderWindow = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: NSScreen.main!.frame.width, height: NSScreen.main!.frame.height), styleMask: [.borderless, .nonactivatingPanel],backing: .buffered, defer: false)
        reminderWindow.level = .mainMenu
        reminderWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        reminderWindow.escKeyCallback = hideReminder
        
        let textView = NSTextView()
        textView.textStorage?.append(NSAttributedString("take a break"))
        reminderWindow.contentView? = NSHostingView(rootView: PanelView())
        
        print("inited \(Date())")
        scheduleShowReminder()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
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
    
    func scheduleHideReminder() {
        if (reminderTimer != nil) {
            reminderTimer!.invalidate()
        }
        reminderTimer = Timer.scheduledTimer(timeInterval: REMINDER_LENGTH_SECONDS,
                                             target: self,
                                             selector: #selector(hideReminder),
                                             userInfo: nil,
                                             repeats: false)
    }
    
    @objc func showReminder() {
        print("Reminder triggered \(Date())")

        reminderWindow.alphaValue = 0
        //reminderWindow.orderFrontRegardless()
        reminderWindow.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 1
            reminderWindow.animator().alphaValue = 1
        }, completionHandler: nil)
        scheduleHideReminder()
    }
    
    @objc func hideReminder() {
        print("Reminder ended \(Date())")
    
        reminderWindow.alphaValue = 1
        //reminderWindow.orderFrontRegardless()
        reminderWindow.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ (context) -> Void in
            context.duration = 1
            reminderWindow.animator().alphaValue = 0
        }, completionHandler: {
            self.reminderWindow.close()
        })
        scheduleShowReminder()
    }

    @objc func statusBarButtonClick(_ sender: Any) {
        let event = NSApp.currentEvent!
        if event.type == NSEvent.EventType.leftMouseUp {
            print("status bar button left-clicked")
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

