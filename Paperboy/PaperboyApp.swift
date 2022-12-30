//
//  PaperboyApp.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import SwiftUI
import CoreData

@main
struct PaperboyApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
#if os(macOS)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { notification in
                    
                    // Nothing we can do here...
                    try? persistenceController.save()
                }
                .frame(minWidth: 600, minHeight: 500)
#elseif os(iOS)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { notification in
                    
                    try? persistenceController.save()
                }
#endif
        }
    }
}
