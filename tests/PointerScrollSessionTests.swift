import AppKit

@main
struct PointerScrollSessionTests {
    @MainActor
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let suite = "huuuiii.PointerScrollSessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "naturalScrolling")
        let settings = ScrollSettings(in: defaults)
        let origin = CGPoint(x: 200, y: 300)
        var pinned: [CGPoint] = []
        var output: [CGEvent] = []
        var stops: [String?] = []
        let session = PointerScrollSession(settings: settings, origin: origin, modifiers: .control,
            warp: { point in pinned.append(point); return .success },
            post: { event, _ in output.append(event) }, onStop: { stops.append($0) })

        for point in [origin, CGPoint.zero, CGPoint(x: -10000, y: 10000)] {
            for direction in [1, -1, 1] {
                let mouse = movement(at: point, deltaX: 2 * direction, deltaY: -3 * direction)
                assert(session.handle(.mouseMoved, event: mouse) == nil)
                assert(pinned.last == origin)
                assert(output.last!.location == origin)
                assert(output.last!.flags == .maskAlphaShift)
                assert(output.last!.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == Int64(60 * direction))
                assert(output.last!.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == Int64(-40 * direction))
            }
        }
        assert(output.count == 9 && stops.isEmpty)
        let released = movement(at: origin, deltaX: 1, deltaY: 1)
        released.flags = []
        assert(session.handle(.mouseMoved, event: released) === released)
        assert(stops.count == 1 && stops[0] == nil)
        assert(session.handle(.mouseMoved, event: released) === released)
        assert(stops.count == 1 && output.count == 9)

        let failed = PointerScrollSession(settings: settings, origin: origin, modifiers: .control,
            warp: { _ in .failure }, post: { _, _ in assertionFailure("Posted after a cursor failure") },
            onStop: { stops.append($0) })
        let mouse = movement(at: origin, deltaX: 1, deltaY: 1)
        assert(failed.handle(.mouseMoved, event: mouse) === mouse)
        assert(stops.count == 2 && stops.last! != nil)

        let disabled = PointerScrollSession(settings: settings, origin: origin, modifiers: .control,
            warp: { _ in .success }, post: { _, _ in assertionFailure("Posted after tap disable") },
            onStop: { stops.append($0) })
        assert(disabled.handle(.tapDisabledByTimeout, event: mouse) === mouse)
        assert(stops.count == 3 && stops.last! != nil)
        assert(disabled.handle(.mouseMoved, event: mouse) === mouse)

        let cancelled = PointerScrollSession(settings: settings, origin: origin, modifiers: .control,
            warp: { _ in assertionFailure("Warped after cancellation"); return .success },
            post: { _, _ in assertionFailure("Posted after cancellation") }, onStop: { _ in assertionFailure("Stopped twice") })
        cancelled.stop()
        cancelled.stop()
        assert(cancelled.handle(.mouseMoved, event: mouse) === mouse)

        defaults.set(false, forKey: "xEnabled")
        defaults.set(false, forKey: "yEnabled")
        let noAxes = PointerScrollSession(settings: ScrollSettings(in: defaults), origin: origin, modifiers: .control,
            warp: { _ in assertionFailure("Pinned the cursor with both axes disabled"); return .success },
            post: { _, _ in assertionFailure("Scrolled with both axes disabled") }, onStop: { assert($0 == nil) })
        assert(noAxes.handle(.mouseMoved, event: mouse) === mouse)
        print("Pinned scrolling, raw deltas, reversals, release, cancellation, cursor failure, and tap disable checks passed.")
    }

    static func movement(at point: CGPoint, deltaX: Int, deltaY: Int) -> CGEvent {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)!
        event.flags = [.maskControl, .maskAlphaShift]
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(deltaX))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(deltaY))
        return event
    }
}
