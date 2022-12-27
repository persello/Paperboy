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
        nyd.title = "Repubblica"
        nyd.url = URL(string: "https://www.repubblica.it/rss/homepage/rss2.0.xml")!
        
        let ninetofivemac = FeedModel(context: controller.container.viewContext)
        ninetofivemac.title = "9to5Mac"
        ninetofivemac.url = URL(string: "https://9to5mac.com/feed")
        
        return controller
    }()
    
    
    /// The inner container.
    let container: NSPersistentContainer
    
    /// Create a new Core Data Persistence Controller.
    /// - Parameter inMemory: Location of the stored data. If true, data will be volatile.
    init(inMemory: Bool = false) {
        
        if inMemory {
            container = NSPersistentContainer(name: "Paperboy")
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let cloudKitContainer = NSPersistentCloudKitContainer(name: "Paperboy")
            try? cloudKitContainer.initializeCloudKitSchema()
            container = cloudKitContainer
            container.viewContext.automaticallyMergesChangesFromParent = true
        }
        
        container.loadPersistentStores { description, error in
            if let error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
    }
    
    func save() throws {
        let context = container.viewContext

        if context.hasChanges {
            try context.save()
        }
    }
}
