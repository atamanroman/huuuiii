import AppKit

@MainActor
final class PointerScrollSession {
    typealias Stop = @MainActor () -> Void
    private let settings: ScrollSettings
    private let origin: CGPoint
    private let modifiers: NSEvent.ModifierFlags
    private let warp: (CGPoint) -> CGError
    private let post: (CGEvent, CGEventTapProxy?) -> Void
    private let onStop: (String?) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var stopped = false

    init(settings: ScrollSettings, origin: CGPoint, modifiers: NSEvent.ModifierFlags,
         warp: @escaping (CGPoint) -> CGError = CGWarpMouseCursorPosition,
         post: @escaping (CGEvent, CGEventTapProxy?) -> Void = { event, proxy in event.tapPostEvent(proxy) },
         onStop: @escaping (String?) -> Void) {
        self.settings = settings
        self.origin = origin
        self.modifiers = modifiers
        self.warp = warp
        self.post = post
        self.onStop = onStop
    }

    isolated deinit {
        stop()
    }

    static func start(settings: ScrollSettings, origin: CGPoint, modifiers: NSEvent.ModifierFlags,
                      onStop: @escaping (String?) -> Void) -> Stop? {
        let session = PointerScrollSession(settings: settings, origin: origin, modifiers: modifiers, onStop: onStop)
        guard session.install() else { return nil }
        return { session.stop() }
    }

    private func install() -> Bool {
        let mask = CGEventMask(1) << CGEventType.mouseMoved.rawValue
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { proxy, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                // The event tap is registered only on the main run loop.
                let consumed = MainActor.assumeIsolated {
                    let session = Unmanaged<PointerScrollSession>.fromOpaque(context).takeUnretainedValue()
                    return session.handle(type, event: event, proxy: proxy) == nil
                }
                return consumed ? nil : Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func handle(_ type: CGEventType, event: CGEvent, proxy: CGEventTapProxy? = nil) -> CGEvent? {
        guard !stopped else { return event }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            finish("Pointer interception was disabled. Check input access and try again.")
            return event
        }
        guard type == .mouseMoved else { return event }
        let held = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        guard ModifierBinding.matches(held, required: modifiers), !NSApp.isActive,
              settings.horizontal || settings.vertical else {
            finish(nil)
            return event
        }
        guard warp(origin) == .success else {
            finish("Could not hold the pointer at the scroll target. Try again.")
            return event
        }
        if let scroll = settings.event(for: event, activationModifiers: modifiers) {
            scroll.location = origin
            post(scroll, proxy)
        }
        return nil
    }

    func stop() {
        stopped = true
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }

    private func finish(_ message: String?) {
        stop()
        onStop(message)
    }
}
