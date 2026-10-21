import AppKit

enum ModifierBinding {
    static let preferenceKey = "modifierFlags"
    static let supported: NSEvent.ModifierFlags = [.control, .option, .shift, .command, .function]
    private static let choices: [(NSEvent.ModifierFlags, String, String)] = [
        (.control, "Control", "⌃"),
        (.option, "Option", "⌥"),
        (.shift, "Shift", "⇧"),
        (.command, "Command", "⌘"),
        (.function, "Function", "fn")
    ]

    static func flags(for rawValue: Int) -> NSEvent.ModifierFlags {
        guard rawValue > 0 else { return .option }
        let flags = NSEvent.ModifierFlags(rawValue: UInt(rawValue)).intersection(supported)
        return flags.isEmpty ? .option : flags
    }

    static func value(in defaults: UserDefaults) -> NSEvent.ModifierFlags {
        if let rawValue = defaults.object(forKey: preferenceKey) as? Int {
            return flags(for: rawValue)
        }
        let legacy = defaults.string(forKey: "modifier") ?? "option"
        return choices.first { $0.1.lowercased() == legacy }?.0 ?? .option
    }

    static func migrate(in defaults: UserDefaults) {
        defaults.set(Int(value(in: defaults).rawValue), forKey: preferenceKey)
    }

    static func matches(_ held: NSEvent.ModifierFlags, required: NSEvent.ModifierFlags) -> Bool {
        !required.isEmpty && held.intersection(supported) == required
    }

    static func symbols(for flags: NSEvent.ModifierFlags) -> String {
        choices.filter { flags.contains($0.0) }.map(\.2).joined(separator: " ")
    }

    static func accessibilityLabel(for flags: NSEvent.ModifierFlags) -> String {
        choices.filter { flags.contains($0.0) }.map(\.1).joined(separator: " + ")
    }
}

struct ModifierCapture {
    private(set) var held: NSEvent.ModifierFlags
    private(set) var candidate: NSEvent.ModifierFlags = []

    init(held: NSEvent.ModifierFlags = []) {
        self.held = held.intersection(ModifierBinding.supported)
    }

    mutating func update(_ flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags? {
        let current = flags.intersection(ModifierBinding.supported)
        if !current.subtracting(held).isEmpty {
            candidate = current
        }
        held = current
        guard current.isEmpty, !candidate.isEmpty else { return nil }
        let result = candidate
        candidate = []
        return result
    }
}

struct ScrollActivation {
    private var generation = 0
    private(set) var isRequested = false

    mutating func request() -> Int {
        generation += 1
        isRequested = true
        return generation
    }

    mutating func cancel() {
        generation += 1
        isRequested = false
    }

    func isCurrent(_ request: Int) -> Bool {
        isRequested && request == generation
    }
}
