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
        PermissionsService.acquireAccessibilityPrivileges()
        permissionsService.pollAccessibilityPrivileges(onTrusted: self.scrollMonitor)
    }
    
    func scrollMonitor() {
        guard flagsMonitor == nil else { return }
        var mouseMonitor: Any?
        var initialPos: CGPoint?
        var lastPos: CGPoint?
        var lastDelta: CGPoint?
        var activation = ScrollActivation()
        stopScrolling = {
            activation.cancel()
            if let mouseMonitor = mouseMonitor {
                NSEvent.removeMonitor(mouseMonitor)
            }
            mouseMonitor = nil
            if let initialPos, lastPos != nil {
                let mouseEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: initialPos, mouseButton: .left)
                mouseEvent?.post(tap: .cghidEventTap)
            }
            initialPos = nil
            lastPos = nil
            lastDelta = nil
        }
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            let required = ModifierBinding.value(in: .standard)
            let matches = ModifierBinding.matches(event.modifierFlags, required: required) && !NSApp.isActive
            guard matches != activation.isRequested else { return }
            self.stopScrolling?()
            if matches {
                let request = activation.request()

                let triggerDelayAny = UserDefaults.standard
                    .object(forKey: "triggerDelay")
                let triggerDelay = triggerDelayAny != nil ? triggerDelayAny as! Double : 0.0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + (triggerDelay / 1000.0)) {
                    if !activation.isCurrent(request) || NSApp.isActive {
                        return
                    }
                    let scrollSpeedAny = UserDefaults.standard
                        .object(forKey: "scrollSpeed")
                    let scrollSpeed = scrollSpeedAny != nil ? scrollSpeedAny as! CGFloat : 20.0
                    
                    let naturalScrollingAny = UserDefaults.standard.object(forKey: "naturalScrolling")
                    let naturalScrolling = naturalScrollingAny != nil ? naturalScrollingAny as! Bool : true
                    let xEnabledAny = UserDefaults.standard.object(forKey: "xEnabled")
                    let xEnabled = xEnabledAny != nil ? xEnabledAny as! Bool : true
                    let yEnabledAny = UserDefaults.standard.object(forKey: "yEnabled")
                    let yEnabled = yEnabledAny != nil ? yEnabledAny as! Bool : true
                    
                    initialPos = CGEvent(source: nil)!.location
                    mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                        let pos = CGEvent(source: nil)!.location
                        if let lastPos = lastPos {
                            let delta = CGPoint(x: lastPos.x - pos.x, y: lastPos.y - pos.y)
                            if delta == CGPoint() {
                                return
                            }
                            var scroll = true
                            if let lastDelta = lastDelta {
                                if delta == CGPoint(x:-lastDelta.x,y:-lastDelta.y) {
                                    scroll = false
                                }
                            }
                            if scroll {
                                var x: Int32 = 0
                                var y: Int32 = 0
                                
                                if xEnabled {
                                    x = Int32(delta.x * scrollSpeed)
                                }
                                if yEnabled {
                                    y = Int32(delta.y * scrollSpeed)
                                }
                                
                                if naturalScrolling {
                                    x = -x
                                    y = -y
                                }
                                
                                let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0)
                                scrollEvent?.post(tap: CGEventTapLocation.cghidEventTap)
                            }
                            lastDelta=delta
                        }
                        lastPos = pos
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
