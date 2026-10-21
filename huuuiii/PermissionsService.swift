//
//  PermissionsService.swift
//  huuuiii
//
//  Created by Lucas Rott on 07.09.24.
//

import Cocoa
import SwiftUI
// The SDK exposes this immutable option key as a mutable C global.
@preconcurrency import var ApplicationServices.kAXTrustedCheckOptionPrompt

@MainActor
final class PermissionsService: ObservableObject {
    static let shared = PermissionsService()
    @Published private(set) var isTrusted: Bool
    private let checkTrust: () -> Bool
    private var onChange: ((Bool) -> Void)?
    private var pollingTask: Task<Void, Never>?

    init(checkTrust: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.checkTrust = checkTrust
        isTrusted = checkTrust()
    }

    deinit {
        pollingTask?.cancel()
    }

    func startMonitoring(onChange: @escaping (Bool) -> Void) {
        stopMonitoring()
        refresh()
        self.onChange = onChange
        onChange(isTrusted)
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                self?.refresh()
            }
        }
    }

    func refresh() {
        let trusted = checkTrust()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        onChange?(trusted)
    }

    func stopMonitoring() {
        pollingTask?.cancel()
        pollingTask = nil
        onChange = nil
    }

    static var settingsName: String {
        if #available(macOS 27, *) { return "Device Control and Data Access" }
        return "Accessibility"
    }

    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    static func acquireAccessibilityPrivileges() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
