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
        print("Preference validation, normalization, safe conversion, and scroll output checks passed.")
    }
}
