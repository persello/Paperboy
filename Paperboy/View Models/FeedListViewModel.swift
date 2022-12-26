//
//  FeedListViewModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 26/12/22.
//

import Foundation
import CoreData

struct FeedListViewModel: Hashable, Equatable, Identifiable {
    enum Content: Equatable, Hashable {
        case folder(FeedFolderModel)
        case feed(FeedModel)
    }
    
    let children: [FeedListViewModel]?
    let content: Content
    let id: NSManagedObjectID
    
    init(folder: FeedFolderModel) {
        guard let feedSet = folder.feeds else {
            self.children = nil
            self.content = .folder(folder)
            self.id = folder.objectID
            
            return
        }
        
        let feeds: [FeedModel] = Array(feedSet.allObjects.compactMap({ item in
            item as? FeedModel
        }))
        
        self.children = feeds.map({ feed in
            FeedListViewModel(feed: feed)
        })
        
        self.content = .folder(folder)
        self.id = folder.objectID
    }
    
    init(feed: FeedModel) {
        self.content = .feed(feed)
        self.children = nil
        self.id = feed.objectID
    }
    
    static func == (lhs: FeedListViewModel, rhs: FeedListViewModel) -> Bool {
        lhs.content == rhs.content
    }
    
    func hash(into hasher: inout Hasher) {
        content.hash(into: &hasher)
    }
}
