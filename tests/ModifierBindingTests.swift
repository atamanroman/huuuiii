import AppKit

@main
struct ModifierBindingTests {
    static func main() {
        let suite = "huuuiii.ModifierBindingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        assert(ModifierBinding.value(in: defaults) == .option)
        let legacyBindings: [(String, NSEvent.ModifierFlags)] = [
            ("control", .control), ("option", .option), ("shift", .shift),
            ("command", .command), ("function", .function)
        ]
        for (name, flag) in legacyBindings {
            defaults.removeObject(forKey: ModifierBinding.preferenceKey)
            defaults.set(name, forKey: "modifier")
            ModifierBinding.migrate(in: defaults)
            assert(ModifierBinding.value(in: defaults) == flag)
            assert(defaults.integer(forKey: ModifierBinding.preferenceKey) == Int(flag.rawValue))
            var single = ModifierCapture()
            assert(single.update(flag) == nil)
            assert(single.update([]) == flag)
        }

        let combination: NSEvent.ModifierFlags = [.control, .option]
        defaults.set(Int(combination.rawValue), forKey: ModifierBinding.preferenceKey)
        ModifierBinding.migrate(in: defaults)
        assert(ModifierBinding.value(in: defaults) == combination)
        assert(ModifierBinding.matches(combination, required: combination))
        assert(ModifierBinding.matches([.control, .option, .capsLock], required: combination))
        assert(!ModifierBinding.matches(.control, required: combination))
        assert(!ModifierBinding.matches([.control, .option, .shift], required: combination))
        assert(!ModifierBinding.matches([], required: []))
        assert(ModifierBinding.flags(for: 0) == .option)
        assert(ModifierBinding.flags(for: -1) == .option)
        assert(ModifierBinding.flags(for: Int(NSEvent.ModifierFlags.capsLock.rawValue)) == .option)
        assert(ModifierBinding.symbols(for: combination) == "⌃ ⌥")
        assert(ModifierBinding.accessibilityLabel(for: combination) == "Control + Option")

        var capture = ModifierCapture()
        assert(capture.update(.control) == nil)
        assert(capture.update(combination) == nil)
        assert(capture.candidate == combination)
        assert(capture.update(.option) == nil)
        assert(capture.update([]) == combination)
        assert(capture.update([]) == nil)

        capture = ModifierCapture()
        assert(capture.update(.option) == nil)
        assert(capture.update(combination) == nil)
        assert(capture.update(.control) == nil)
        assert(capture.update(.capsLock) == combination)
        assert(capture.update([]) == nil)

        capture = ModifierCapture(held: combination)
        assert(capture.update(.option) == nil)
        assert(capture.update([]) == nil)
        assert(capture.update(.shift) == nil)
        assert(capture.update([]) == .shift)

        capture = ModifierCapture()
        assert(capture.update(.control) == nil)
        assert(capture.update(combination) == nil)
        assert(capture.update(.option) == nil)
        assert(capture.update([.option, .shift]) == nil)
        assert(capture.update(.shift) == nil)
        assert(capture.update([]) == [.option, .shift])

        capture = ModifierCapture()
        assert(capture.update(.capsLock) == nil)
        assert(capture.update([]) == nil)

        var activation = ScrollActivation()
        let firstPress = activation.request()
        assert(activation.isCurrent(firstPress))
        activation.cancel()
        assert(!activation.isCurrent(firstPress))
        let secondPress = activation.request()
        assert(!activation.isCurrent(firstPress))
        assert(activation.isCurrent(secondPress))
        activation.cancel()
        assert(!activation.isCurrent(secondPress))

        print("Modifier migration, exact matching, recording, and delayed activation checks passed.")
    }
}
