//
//  AppDelegate.swift
//  huuuiii
//
//  Created by Lucas Rott on 21.08.24.
//

import Foundation
import Cocoa
import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published private(set) var inputError: String?
    private var flagsMonitor: Any?
    private let permissionsService: PermissionsService
    private let defaults: UserDefaults
    private let addMonitor: (NSEvent.EventTypeMask, @escaping (NSEvent) -> Void) -> Any?
    private let removeMonitor: (Any) -> Void
    private var stopScrolling: (() -> Void)?

    override convenience init() {
        self.init(permissionsService: .shared)
    }

    init(permissionsService: PermissionsService, defaults: UserDefaults = .standard,
         addMonitor: @escaping (NSEvent.EventTypeMask, @escaping (NSEvent) -> Void) -> Any? = NSEvent.addGlobalMonitorForEvents,
         removeMonitor: @escaping (Any) -> Void = NSEvent.removeMonitor) {
        self.permissionsService = permissionsService
        self.defaults = defaults
        self.addMonitor = addMonitor
        self.removeMonitor = removeMonitor
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        ModifierBinding.migrate(in: defaults)
        ScrollSettings.normalize(in: defaults)
        startMonitoring()
        PermissionsService.acquireAccessibilityPrivileges()
    }

    func startMonitoring() {
        permissionsService.startMonitoring { [weak self] trusted in
            guard let self else { return }
            if trusted {
                self.scrollMonitor()
            } else {
                self.stopMonitoring()
                self.inputError = nil
            }
        }
    }
    
    func scrollMonitor() {
        guard flagsMonitor == nil else { return }
        inputError = nil
        var mouseMonitor: Any?
        var initialPos: CGPoint?
        var pointerMoved = false
        var activation = ScrollActivation()
        stopScrolling = { [removeMonitor] in
            activation.cancel()
            if let mouseMonitor = mouseMonitor {
                removeMonitor(mouseMonitor)
            }
            mouseMonitor = nil
            if let initialPos, pointerMoved {
                let mouseEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: initialPos, mouseButton: .left)
                mouseEvent?.post(tap: .cghidEventTap)
            }
            initialPos = nil
            pointerMoved = false
        }
        flagsMonitor = addMonitor(.flagsChanged) { event in
            let required = ModifierBinding.value(in: self.defaults)
            let matches = ModifierBinding.matches(event.modifierFlags, required: required) && !NSApp.isActive
            guard matches != activation.isRequested else { return }
            self.stopScrolling?()
            if matches {
                let request = activation.request()

                let triggerDelay = ScrollSettings(in: self.defaults).triggerDelay
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (triggerDelay / 1000.0)) {
                    if !activation.isCurrent(request) || NSApp.isActive {
                        return
                    }
                    let settings = ScrollSettings(in: self.defaults)
                    
                    guard let origin = CGEvent(source: nil)?.location else {
                        self.failMonitoring("Could not read the pointer location. Try again.")
                        return
                    }
                    initialPos = origin
                    mouseMonitor = self.addMonitor(.mouseMoved) { movement in
                        if movement.deltaX != 0 || movement.deltaY != 0 { pointerMoved = true }
                        settings.event(for: movement, at: origin, activationModifiers: required)?.post(tap: .cghidEventTap)
                    }
                    if mouseMonitor == nil {
                        self.failMonitoring("Could not monitor pointer movement. Check input access and try again.")
                    }
                }
            }
        }
        if flagsMonitor == nil {
            failMonitoring("Could not monitor modifier keys. Check input access and try again.")
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        pauseScrolling()
        permissionsService.refresh()
    }

    func pauseScrolling() {
        stopScrolling?()
    }
    
    func retryMonitoring() {
        permissionsService.refresh()
        if permissionsService.isTrusted { scrollMonitor() }
    }

    private func failMonitoring(_ message: String) {
        stopMonitoring()
        inputError = message
    }

    private func stopMonitoring() {
        stopScrolling?()
        stopScrolling = nil
        if let flagsMonitor = flagsMonitor {
            removeMonitor(flagsMonitor)
        }
        flagsMonitor = nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionsService.stopMonitoring()
        stopMonitoring()
    }
}
