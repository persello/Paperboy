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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [FeedFolderModel.self, FeedModel.self, FeedItemModel.self], isAutosaveEnabled: true)
#if os(macOS)
                .frame(minWidth: 600, minHeight: 500)
#endif
        }
    }
}
