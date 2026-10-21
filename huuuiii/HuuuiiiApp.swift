//
//  HuuuiiiApp.swift
//  huuuiii
//
//  Created by Lucas Rott on 20.08.24.
//

import SwiftUI

@main
struct HuuuiiiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("huuuiii", image: "Icon") {
            ContentView(stopScrolling: appDelegate.pauseScrolling, inputError: appDelegate.inputError, retryInput: appDelegate.retryMonitoring)
        }.menuBarExtraStyle(.window)

    }
}
