//
//  PersistenceController.swift
//  Paperboy
//
//  Created by Riccardo Persello on 08/12/22.
//

import Foundation
import CoreData

struct PersistenceController {
    
    /// A shared instance of the `PersistenceController`.
    static let shared = PersistenceController()
    
    /// A shared instance of the `PersistenceController`, populated with fake data and no storage persistence.
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        
        // Populate with fake data.
        let nyd = FeedModel(context: controller.container.viewContext)
        nyd.title = "New York Times Daily"
        nyd.link = "https://feeds.simplecast.com/54nAGcIl"
        
        let ninetofivemac = FeedModel(context: controller.container.viewContext)
        ninetofivemac.title = "9to5Mac"
        ninetofivemac.link = "https://9to5mac.com/feed"
        
        return controller
    }()
    
    
    /// The inner container.
    let container: NSPersistentContainer
    
    /// Create a new Core Data Persistence Controller.
    /// - Parameter inMemory: Location of the stored data. If true, data will be volatile.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Paperboy")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // TODO: Show some error here.
            }
        }
    }
}
