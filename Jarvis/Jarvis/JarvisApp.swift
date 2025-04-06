//
//  JarvisApp.swift
//  Jarvis
//
//  Created by Aarush Agarwal on 3/22/25.
//

import SwiftUI
import SwiftData

@main
struct JarvisApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: 500, minHeight: 700)
        }
        .modelContainer(sharedModelContainer)
    }
}
