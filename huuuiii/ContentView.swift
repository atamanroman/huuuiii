//
//  ContentView.swift
//  huuuiii
//
//  Created by Lucas Rott on 21.08.24.
//

import SwiftUI
import LaunchAtLogin

struct ContentView: View {
    let stopScrolling: () -> Void

    @AppStorage(ModifierBinding.preferenceKey) private var modifierFlags = Int(NSEvent.ModifierFlags.option.rawValue)
    @AppStorage("scrollSpeed") private var scrollSpeed = 20.0
    @AppStorage("naturalScrolling") private var naturalScrolling = true
    @AppStorage("xEnabled") private var xEnabled = true
    @AppStorage("yEnabled") private var yEnabled = true
    @AppStorage("needsPermission") private var needsPermission = false
    @AppStorage("triggerDelay") private var triggerDelay = 0.0
    
    var body: some View {
        VStack {
            if needsPermission {
                Text("This app needs accessbility access!")
            } else {
                Form {
                    LabeledContent("General:") {
                        LaunchAtLogin.Toggle()
                    }
                    Slider(value: $triggerDelay, in: 0...2000, step: 100.0) {
                        Text("Trigger Delay:")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("2000")
                    }
                    Text("\(triggerDelay, specifier: "%.0f") ms")
                    LabeledContent("Scroll modifiers:") {
                        ModifierRecorder(modifierFlags: $modifierFlags, onStartRecording: stopScrolling)
                            .frame(width: 150)
                    }
                    LabeledContent("Scroll Direction:") {
                        Toggle("Natural Scrolling", isOn: $naturalScrolling)
                    }
                    HStack {
                        Toggle("X", isOn: $xEnabled)
                        Toggle("Y", isOn: $yEnabled)
                    }
                    Slider(value: $scrollSpeed, in: 1...100) {
                        Text("Scroll Speed:")
                    } minimumValueLabel: {
                        Text("1")
                    } maximumValueLabel: {
                        Text("100")
                    }
                    Text("\(scrollSpeed, specifier: "%.0f")")
                }.multilineTextAlignment(.leading)
            }
            Divider()
            Button("Quit", action: { NSApplication.shared.terminate(nil) })
        }.padding(10)
        .onAppear(perform: stopScrolling)
    }
}
