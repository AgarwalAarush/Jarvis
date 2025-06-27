//
//  JarvisApp.swift
//  Jarvis
//
//  Created by Aarush Agarwal on 3/22/25.
//

import SwiftUI
import CoreData

@main
struct JarvisApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataController = DataController()
    @StateObject private var stateManager = JarvisStateManager.shared
    @StateObject private var backendManager = BackendProcessManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 500, minHeight: 700)
                .environment(\.managedObjectContext, dataController.container.viewContext)
                .environmentObject(dataController)
                .environmentObject(stateManager)
                .environmentObject(backendManager)
                .onAppear {
                    backendManager.startBackend()
                }
        }
        .commands {
            // Add custom menu commands
            CommandGroup(after: .appInfo) {
                Button("Settings") {
                    stateManager.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Divider()
                
                Button("Switch to Voice Mode") {
                    stateManager.switchMode(to: .voice)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                
                Button("Switch to Chat Mode") {
                    stateManager.switchMode(to: .chat)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}
