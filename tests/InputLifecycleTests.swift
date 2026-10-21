import AppKit

@main
struct InputLifecycleTests {
    @MainActor
    static func main() async {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let suite = "huuuiii.InputLifecycleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var trusted = false
        let service = PermissionsService(checkTrust: { trusted })
        var starts = 0
        var removals = 0
        var rejectMonitor = false
        var rejectMovement = false
        var movementStarts = 0
        var flagsHandler: ((NSEvent) -> Void)?
        let delegate = AppDelegate(permissionsService: service, defaults: defaults, addMonitor: { mask, handler in
            if mask == .mouseMoved {
                movementStarts += 1
                return rejectMovement ? nil : NSObject()
            }
            starts += 1
            flagsHandler = handler
            return rejectMonitor ? nil : NSObject()
        }, removeMonitor: { _ in removals += 1 })
        delegate.startMonitoring()
        assert(starts == 0)
        trusted = true
        service.refresh()
        assert(starts == 1 && delegate.inputError == nil)
        service.refresh()
        delegate.retryMonitoring()
        assert(starts == 1)
        let press = NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: .option, timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 58)!
        defaults.set(100, forKey: "triggerDelay")
        flagsHandler?(press)
        trusted = false
        service.refresh()
        assert(removals == 1)
        try? await Task.sleep(for: .milliseconds(150))
        assert(movementStarts == 0, "Revocation left a delayed activation alive")
        defaults.set(0, forKey: "triggerDelay")
        trusted = true
        rejectMonitor = true
        service.refresh()
        assert(starts == 2 && delegate.inputError != nil)
        rejectMonitor = false
        delegate.retryMonitoring()
        assert(starts == 3 && delegate.inputError == nil)

        rejectMovement = true
        flagsHandler?(press)
        try? await Task.sleep(for: .milliseconds(100))
        assert(delegate.inputError?.contains("pointer movement") == true)
        assert(removals == 2)
        delegate.retryMonitoring()
        assert(starts == 4 && delegate.inputError == nil)
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
        assert(removals == 3)
        trusted = false
        service.refresh()
        trusted = true
        service.refresh()
        assert(starts == 4)
        flagsHandler = nil
        print("Monitor grant, revocation, retry, failed pointer setup, and termination checks passed.")
    }
}
