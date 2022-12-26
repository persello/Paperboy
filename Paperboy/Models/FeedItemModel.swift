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
}
