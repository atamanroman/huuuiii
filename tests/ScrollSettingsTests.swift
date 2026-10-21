import AppKit

@main
struct ScrollSettingsTests {
    static func main() {
        let suite = "huuuiii.ScrollSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        var settings = ScrollSettings(in: defaults)
        assert(settings.speed == 20 && settings.triggerDelay == 0)
        assert(settings.natural && settings.horizontal && settings.vertical)
        for invalid in ["fast", true, [1, 2]] as [Any] {
            defaults.set(invalid, forKey: "scrollSpeed")
            defaults.set(invalid, forKey: "triggerDelay")
            settings = ScrollSettings(in: defaults)
            assert(settings.speed == 20 && settings.triggerDelay == 0)
        }
        for invalid in [Double.nan, Double.infinity, -Double.infinity] {
            defaults.set(invalid, forKey: "scrollSpeed")
            defaults.set(invalid, forKey: "triggerDelay")
            settings = ScrollSettings(in: defaults)
            assert(settings.speed == 20 && settings.triggerDelay == 0)
        }
        defaults.set(-100, forKey: "scrollSpeed")
        defaults.set(-100, forKey: "triggerDelay")
        settings = ScrollSettings(in: defaults)
        assert(settings.speed == 1 && settings.triggerDelay == 0)
        defaults.set(Double.greatestFiniteMagnitude, forKey: "scrollSpeed")
        defaults.set(Double.greatestFiniteMagnitude, forKey: "triggerDelay")
        settings = ScrollSettings(in: defaults)
        assert(settings.speed == 100 && settings.triggerDelay == 2000)
        assert(settings.scrollDelta(Double.greatestFiniteMagnitude, enabled: true) == Int32.min)
        assert(settings.scrollDelta(-Double.greatestFiniteMagnitude, enabled: true) == Int32.max)
        assert(settings.scrollDelta(.nan, enabled: true) == 0)
        assert(settings.scrollDelta(.infinity, enabled: true) == 0)
        assert(settings.scrollDelta(10, enabled: false) == 0)

        for invalid in ["false", 0, [false]] as [Any] {
            defaults.set(invalid, forKey: "naturalScrolling")
            defaults.set(invalid, forKey: "xEnabled")
            defaults.set(invalid, forKey: "yEnabled")
            settings = ScrollSettings(in: defaults)
            assert(settings.natural && settings.horizontal && settings.vertical)
        }
        defaults.set(false, forKey: "naturalScrolling")
        defaults.set(false, forKey: "xEnabled")
        defaults.set(false, forKey: "yEnabled")
        ScrollSettings.normalize(in: defaults)
        settings = ScrollSettings(in: defaults)
        assert(!settings.natural && !settings.horizontal && !settings.vertical)
        assert(defaults.double(forKey: "scrollSpeed") == 100)
        assert(defaults.double(forKey: "triggerDelay") == 2000)

        defaults.set(20, forKey: "scrollSpeed")
        defaults.set(true, forKey: "xEnabled")
        defaults.set(true, forKey: "yEnabled")
        settings = ScrollSettings(in: defaults)
        assert(settings.scrollDelta(2.5, enabled: true) == 50)
        assert(settings.scrollDelta(-2.5, enabled: true) == -50)
        assert(settings.event(delta: .zero) == nil)
        let event = settings.event(delta: CGPoint(x: 2, y: -3))!
        assert(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -60)
        assert(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 40)

        let origin = CGPoint(x: 200, y: 300)
        for position in [CGPoint.zero, CGPoint(x: 10000, y: 10000), CGPoint(x: -10000, y: -10000)] {
            for direction in [1, -1, 1] {
                let mouse = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: position, mouseButton: .left)!
                mouse.setIntegerValueField(.mouseEventDeltaX, value: Int64(2 * direction))
                mouse.setIntegerValueField(.mouseEventDeltaY, value: Int64(-3 * direction))
                mouse.flags = []
                let movement = NSEvent(cgEvent: mouse)!
                let scroll = settings.event(for: movement, activationModifiers: .option)!
                guard scroll.location == position else {
                    print("Scroll event reset the pointer from \(position) to \(scroll.location)")
                    exit(1)
                }
                assert(scroll.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == Int64(60 * direction))
                assert(scroll.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == Int64(-40 * direction))
            }
        }
        let bindings: [NSEvent.ModifierFlags] = [.control, .option, .shift, .command, .function, [.control, .option], [.control, .option, .shift, .command, .function]]
        for binding in bindings {
            let mouse = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: origin, mouseButton: .left)!
            let originalFlags = CGEventFlags(rawValue: UInt64(binding.rawValue)).union(.maskAlphaShift)
            mouse.flags = originalFlags
            mouse.setIntegerValueField(.mouseEventDeltaY, value: 1)
            let scroll = settings.event(for: NSEvent(cgEvent: mouse)!, activationModifiers: binding)!
            assert(scroll.flags == .maskAlphaShift)
            assert(mouse.flags == originalFlags)
        }
        let modifiedMouse = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: origin, mouseButton: .left)!
        modifiedMouse.flags = [.maskControl, .maskShift, .maskCommand, .maskAlphaShift]
        modifiedMouse.setIntegerValueField(.mouseEventDeltaY, value: 1)
        let stripped = settings.event(for: NSEvent(cgEvent: modifiedMouse)!, activationModifiers: .control)!
        assert(stripped.flags == [.maskShift, .maskCommand, .maskAlphaShift])
        print("Preference validation, normalization, safe conversion, and scroll output checks passed.")
    }
}
