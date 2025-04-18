import SwiftUI
import Cocoa
import Carbon

@main
struct MouseSetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var savedPosition: CGPoint?
    var inactivityTimer: Timer?
    var lastMouseLocation: CGPoint?
    var eventTap: CFMachPort?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startMouseMonitor()
        registerGlobalHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let eventTap = eventTap {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0),
                                  .commonModes)
        }
    }

    func startMouseMonitor() {
        let mask = (1 << CGEventType.mouseMoved.rawValue)
        if let tap = CGEvent.tapCreate(tap: .cghidEventTap,
                                       place: .headInsertEventTap,
                                       options: .defaultTap,
                                       eventsOfInterest: CGEventMask(mask),
                                       callback: { _, _, event, userInfo in
                                           let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userInfo!).takeUnretainedValue()
                                           appDelegate.mouseMoved(event: event)
                                           return Unmanaged.passRetained(event)
                                       },
                                       userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())) {
            self.eventTap = tap
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func mouseMoved(event: CGEvent) {
        let loc = event.location
        lastMouseLocation = loc
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            self?.savedPosition = loc
            print("Position saved at: \(loc)")
        }
    }

    func registerGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == kVK_ANSI_E {
                self?.restoreMousePosition()
            }
        }
    }

    func restoreMousePosition() {
        guard let pos = savedPosition else {
            print("No saved position.")
            return
        }

        let move = CGEvent(mouseEventSource: nil,
                           mouseType: .mouseMoved,
                           mouseCursorPosition: pos,
                           mouseButton: .left)
        move?.post(tap: .cghidEventTap)
        print("Moved cursor to \(pos)")
    }
}
