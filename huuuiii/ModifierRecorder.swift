import AppKit
import SwiftUI

struct ModifierRecorder: NSViewRepresentable {
    @Binding var modifierFlags: Int
    let onStartRecording: () -> Void

    func makeNSView(context: Context) -> ModifierRecorderField {
        ModifierRecorderField()
    }

    func updateNSView(_ field: ModifierRecorderField, context: Context) {
        field.selectedFlags = ModifierBinding.flags(for: modifierFlags)
        field.onStartRecording = onStartRecording
        field.onCommit = { flags in
            modifierFlags = Int(flags.rawValue)
        }
    }

    static func dismantleNSView(_ field: ModifierRecorderField, coordinator: ()) {
        field.stopRecording()
        field.onStartRecording = nil
        field.onCommit = nil
    }
}

final class ModifierRecorderField: NSTextField, NSTextFieldDelegate {
    var selectedFlags: NSEvent.ModifierFlags = .option {
        didSet {
            if monitor == nil { updateDisplay() }
        }
    }
    var onStartRecording: (() -> Void)?
    var onCommit: ((NSEvent.ModifierFlags) -> Void)?
    private var capture = ModifierCapture()
    private var monitor: Any?

    init() {
        super.init(frame: .zero)
        isBezeled = true
        bezelStyle = .roundedBezel
        alignment = .center
        delegate = self
        placeholderString = "Click to record"
        let instructions = "Hold modifier keys and release to save; press Escape to cancel."
        toolTip = instructions
        setAccessibilityLabel("Scroll modifier binding")
        setAccessibilityHelp(instructions)
        updateDisplay()
    }

    required init?(coder: NSCoder) {
        fatalError("ModifierRecorderField is created programmatically")
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { startRecording() }
        return accepted
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopRecording() }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        stopRecording()
    }

    func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        capture = ModifierCapture()
        updateDisplay()
    }

    private func startRecording() {
        guard monitor == nil else { return }
        onStartRecording?()
        capture = ModifierCapture(held: NSEvent.modifierFlags)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return event }
            guard let editor = self.currentEditor(), self.window?.firstResponder === editor else {
                self.stopRecording()
                return event
            }
            if event.type == .flagsChanged {
                if let flags = self.capture.update(event.modifierFlags) {
                    self.selectedFlags = flags
                    self.stopRecording()
                    self.onCommit?(flags)
                    self.window?.makeFirstResponder(nil)
                } else {
                    self.updateDisplay()
                }
                return event
            }
            if event.keyCode == 53 {
                self.stopRecording()
                self.window?.makeFirstResponder(nil)
            } else if event.keyCode == 48 {
                self.stopRecording()
                return event
            }
            return nil
        }
        updateDisplay()
        if monitor == nil { window?.makeFirstResponder(nil) }
    }

    private func updateDisplay() {
        let recording = monitor != nil
        let flags = recording ? capture.candidate : selectedFlags
        let text = recording && flags.isEmpty ? "Press modifiers…" : ModifierBinding.symbols(for: flags)
        stringValue = text
        currentEditor()?.string = text
        setAccessibilityValue(recording ? "Recording \(ModifierBinding.accessibilityLabel(for: flags))" : ModifierBinding.accessibilityLabel(for: flags))
    }
}
