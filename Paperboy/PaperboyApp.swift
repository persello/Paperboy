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
    let persistenceController = PersistenceController.preview

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
