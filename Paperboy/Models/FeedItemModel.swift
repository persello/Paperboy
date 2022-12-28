//
//  FeedItemModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 08/12/22.
//

import Foundation
import CoreData
import SwiftSoup

extension FeedItemModel {
    
    // MARK: Initialisers.
    convenience init<F: FeedItemProtocol>(from item: F, context: NSManagedObjectContext) {
        self.init(context: context)
        self.articleDescription = item.description
        self.url = item.url
        self.publicationDate = item.publicationDate
        self.title = item.title
    }
    
    // MARK: Public functions.
    public func updateWallpaper() {
        guard wallpaperURL == nil else {
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            guard let description = self.articleDescription else {
                return
            }
            
            let document = try? SwiftSoup.parse(description)
            let image = try? document?.select("img").first()
            guard let src = try? image?.attr("src") else {
                return
            }

            DispatchQueue.main.async {
                self.wallpaperURL = URL(string: src)
            }
        }
    }
    
    // MARK: Computed properties.
    var normalisedTitle: String {
        return title ?? "Unnamed article"
    }
    
    var normalisedContentDescription: String? {
        guard let description = self.articleDescription else {
            return nil
        }
        
        let document = try? SwiftSoup.parse(description)
        let paragraph = try? document?.select("p").first()
        let articleDescription = paragraph?.ownText()
        
        return articleDescription
    }
    
    public override func willSave() {
        self.feed?.objectWillChange.send()
    }
}
