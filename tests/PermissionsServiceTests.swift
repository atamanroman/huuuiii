import AppKit

@main
struct PermissionsServiceTests {
    @MainActor
    static func main() async {
        var trusted = false
        var reads = 0
        let service = PermissionsService(checkTrust: { reads += 1; return trusted })
        assert(!service.isTrusted)
        var changes: [Bool] = []
        service.startMonitoring { changes.append($0) }
        assert(changes == [false])
        service.refresh()
        assert(changes == [false])
        trusted = true
        try? await Task.sleep(for: .milliseconds(1100))
        assert(changes == [false, true])
        service.refresh()
        assert(changes == [false, true])
        trusted = false
        service.refresh()
        trusted = true
        service.refresh()
        assert(changes == [false, true, false, true])
        service.stopMonitoring()
        let stoppedReads = reads
        try? await Task.sleep(for: .milliseconds(1100))
        assert(reads == stoppedReads)
        trusted = false
        service.refresh()
        assert(!service.isTrusted)
        assert(changes == [false, true, false, true])
        service.startMonitoring { changes.append($0) }
        assert(changes == [false, true, false, true, false])
        service.stopMonitoring()
        print("Denied startup, grant, revocation, regrant, and permission polling lifecycle checks passed.")
    }
}
