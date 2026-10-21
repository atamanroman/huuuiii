import AppKit

struct ScrollSettings {
    let speed: Double
    let triggerDelay: Double
    let natural: Bool
    let horizontal: Bool
    let vertical: Bool

    init(in defaults: UserDefaults) {
        speed = Self.number(in: defaults, key: "scrollSpeed", fallback: 20, range: 1...100)
        triggerDelay = Self.number(in: defaults, key: "triggerDelay", fallback: 0, range: 0...2000)
        natural = Self.boolean(in: defaults, key: "naturalScrolling")
        horizontal = Self.boolean(in: defaults, key: "xEnabled")
        vertical = Self.boolean(in: defaults, key: "yEnabled")
    }

    static func normalize(in defaults: UserDefaults) {
        let settings = Self(in: defaults)
        defaults.set(settings.speed, forKey: "scrollSpeed")
        defaults.set(settings.triggerDelay, forKey: "triggerDelay")
        defaults.set(settings.natural, forKey: "naturalScrolling")
        defaults.set(settings.horizontal, forKey: "xEnabled")
        defaults.set(settings.vertical, forKey: "yEnabled")
    }

    func scrollDelta(_ movement: Double, enabled: Bool) -> Int32 {
        guard enabled, movement.isFinite else { return 0 }
        let scaled = movement * speed * (natural ? -1 : 1)
        return Int32(min(Double(Int32.max), max(Double(Int32.min), scaled)))
    }

    func event(delta: CGPoint) -> CGEvent? {
        let x = scrollDelta(delta.x, enabled: horizontal)
        let y = scrollDelta(delta.y, enabled: vertical)
        guard x != 0 || y != 0 else { return nil }
        return CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0)
    }

    func event(for movement: NSEvent, activationModifiers: NSEvent.ModifierFlags) -> CGEvent? {
        let scroll = event(delta: CGPoint(x: -movement.deltaX, y: -movement.deltaY))
        if let location = movement.cgEvent?.location { scroll?.location = location }
        scroll?.flags = CGEventFlags(rawValue: UInt64(movement.modifierFlags.subtracting(activationModifiers).rawValue))
        return scroll
    }

    private static func number(in defaults: UserDefaults, key: String, fallback: Double, range: ClosedRange<Double>) -> Double {
        guard let value = defaults.object(forKey: key) as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return fallback }
        return min(range.upperBound, max(range.lowerBound, value.doubleValue))
    }

    private static func boolean(in defaults: UserDefaults, key: String) -> Bool {
        guard let value = defaults.object(forKey: key) as? NSNumber,
              CFGetTypeID(value) == CFBooleanGetTypeID() else { return true }
        return value.boolValue
    }
}
