//
//  FeedItemModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 08/12/22.
//

import Foundation
import CoreData
import SwiftSoup
import os

extension FeedItemModel {

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedItemModel")
    
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

            Self.logger.info("Fetching wallpaper for \"\(self.normalisedTitle)\".")

            guard let description = self.articleDescription else {
                Self.logger.info("No description for \"\(self.normalisedTitle)\".")
                return
            }
            
            let document = try? SwiftSoup.parse(description)
            let image = try? document?.select("img").first()
            guard let src = try? image?.attr("src") else {
                Self.logger.info("No image found in description of \"\(self.normalisedTitle)\".")
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
        get async {
            guard let description = self.articleDescription else {
                return nil
            }
            
            return await withCheckedContinuation({ continuation in
                let document = try? SwiftSoup.parse(description)
                let paragraph = try? document?.select("p").first()
                continuation.resume(returning: paragraph?.ownText())
            })
        }
    }
    
    public override func willSave() {
        self.feed?.objectWillChange.send()
    }
}
