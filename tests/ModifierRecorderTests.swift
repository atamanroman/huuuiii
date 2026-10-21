import AppKit
import SwiftUI

@main
struct ModifierRecorderTests {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        var selection = Int(NSEvent.ModifierFlags.option.rawValue)
        var recordingStarts = 0
        let hostingView = NSHostingView(rootView: ModifierRecorder(modifierFlags: Binding(
            get: { selection },
            set: { selection = $0 }
        ), onStartRecording: { recordingStarts += 1 }))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.alphaValue = 0
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        flush()
        guard let field = textField(in: hostingView) else { fatalError("Recorder text field missing") }
        precondition(window.makeFirstResponder(field))
        flush()
        precondition(recordingStarts == 1)
        precondition(field.stringValue == "Press modifiers…")
        send(.keyDown, flags: [], keyCode: 0, window: window, characters: "a")
        flush()
        precondition(field.stringValue == "Press modifiers…")
        send(.flagsChanged, flags: .control, keyCode: 59, window: window)
        send(.flagsChanged, flags: [.control, .option], keyCode: 58, window: window)
        precondition(selection == Int(NSEvent.ModifierFlags.option.rawValue))
        send(.flagsChanged, flags: .option, keyCode: 59, window: window)
        precondition(selection == Int(NSEvent.ModifierFlags.option.rawValue))
        send(.flagsChanged, flags: [], keyCode: 58, window: window)
        let chord = Int(NSEvent.ModifierFlags([.control, .option]).rawValue)
        precondition(selection == chord, "Releasing all modifiers did not save the chord")
        flush()
        precondition(field.stringValue == "⌃ ⌥")

        precondition(window.makeFirstResponder(field))
        flush()
        send(.flagsChanged, flags: .command, keyCode: 55, window: window)
        send(.keyDown, flags: .command, keyCode: 53, window: window, characters: "\u{1b}")
        send(.flagsChanged, flags: [], keyCode: 55, window: window)
        flush()
        precondition(selection == chord, "Escape changed the saved chord")
        precondition(field.stringValue == "⌃ ⌥")

        precondition(window.makeFirstResponder(field))
        flush()
        send(.flagsChanged, flags: .shift, keyCode: 56, window: window)
        precondition(window.makeFirstResponder(nil))
        send(.flagsChanged, flags: [], keyCode: 56, window: window)
        flush()
        precondition(selection == chord, "Losing focus saved an incomplete chord")

        precondition(window.makeFirstResponder(field))
        flush()
        send(.flagsChanged, flags: .command, keyCode: 55, window: window)
        window.orderOut(nil)
        window.contentView = nil
        send(.flagsChanged, flags: [], keyCode: 55, window: window)
        flush()
        precondition(selection == chord, "Removing the field left recording active")
        precondition(recordingStarts == 4)
        print("Native recorder focus, save-on-release, Escape, focus-loss, and removal checks passed.")
    }

    @MainActor
    static func flush() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    }

    @MainActor
    static func send(_ type: NSEvent.EventType, flags: NSEvent.ModifierFlags, keyCode: UInt16, window: NSWindow, characters: String = "") {
        let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode)!
        NSApp.sendEvent(event)
    }

    @MainActor
    static func textField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField { return field }
        return view.subviews.lazy.compactMap { textField(in: $0) }.first
    }
}
