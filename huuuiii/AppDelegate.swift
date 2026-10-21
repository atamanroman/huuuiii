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
class AppDelegate: NSObject, NSApplicationDelegate {
    private var flagsMonitor: Any?
    private var permissionsService = PermissionsService.shared
    private var stopScrolling: (() -> Void)?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        ModifierBinding.migrate(in: .standard)
        ScrollSettings.normalize(in: .standard)
        PermissionsService.acquireAccessibilityPrivileges()
        permissionsService.pollAccessibilityPrivileges(onTrusted: self.scrollMonitor)
    }
    
    func scrollMonitor() {
        guard flagsMonitor == nil else { return }
        var mouseMonitor: Any?
        var initialPos: CGPoint?
        var pointerMoved = false
        var activation = ScrollActivation()
        stopScrolling = {
            activation.cancel()
            if let mouseMonitor = mouseMonitor {
                NSEvent.removeMonitor(mouseMonitor)
            }
            mouseMonitor = nil
            if let initialPos, pointerMoved {
                let mouseEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: initialPos, mouseButton: .left)
                mouseEvent?.post(tap: .cghidEventTap)
            }
            initialPos = nil
            pointerMoved = false
        }
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            let required = ModifierBinding.value(in: .standard)
            let matches = ModifierBinding.matches(event.modifierFlags, required: required) && !NSApp.isActive
            guard matches != activation.isRequested else { return }
            self.stopScrolling?()
            if matches {
                let request = activation.request()

                let triggerDelay = ScrollSettings(in: .standard).triggerDelay
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (triggerDelay / 1000.0)) {
                    if !activation.isCurrent(request) || NSApp.isActive {
                        return
                    }
                    let settings = ScrollSettings(in: .standard)
                    
                    guard let origin = CGEvent(source: nil)?.location else {
                        self.pauseScrolling()
                        return
                    }
                    initialPos = origin
                    mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { movement in
                        if movement.deltaX != 0 || movement.deltaY != 0 { pointerMoved = true }
                        settings.event(for: movement, at: origin)?.post(tap: .cghidEventTap)
                    }
                }
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        pauseScrolling()
    }

    func pauseScrolling() {
        stopScrolling?()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        stopScrolling?()
        stopScrolling = nil
        if let flagsMonitor = flagsMonitor {
            NSEvent.removeMonitor(flagsMonitor)
        }
    }
}
