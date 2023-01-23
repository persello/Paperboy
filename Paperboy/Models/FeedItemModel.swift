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
    static let signposter = OSSignposter(logger: logger)
    
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
        
        let signpostID = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval("updateWallpaper", id: signpostID, "\(self.normalisedTitle)")
        
        defer {
            Self.signposter.endInterval("updateWallpaper", state)
        }
        
        guard wallpaperURL == nil else {
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            
            Self.signposter.emitEvent("Getting article description.", id: signpostID)
            Self.logger.info("Fetching wallpaper for \"\(self.normalisedTitle)\" from article description.")

            guard let description = self.articleDescription else {
                Self.logger.info("No description for \"\(self.normalisedTitle)\".")
                return
            }
            
            Self.signposter.emitEvent("Starting HTML parser.", id: signpostID)
            
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
            
            let signpostID = Self.signposter.makeSignpostID()
            let state = Self.signposter.beginInterval("normalisedContentDescription", id: signpostID, "\(self.normalisedTitle)")
            
            defer {
                Self.signposter.endInterval("normalisedContentDescription", state)
            }
            
            guard let description = self.articleDescription else {
                return nil
            }
            
            return await withCheckedContinuation({ continuation in
                
                Self.signposter.emitEvent("Starting HTML parser.", id: signpostID)
                do {
                    let document = try SwiftSoup.parse(description)
                    let paragraph = try document.select("p").first()
                    let body = document.body()
                    let text = try? paragraph?.text(trimAndNormaliseWhitespace: true) ?? body?.text(trimAndNormaliseWhitespace: true)
                    
                    Self.signposter.emitEvent("Found paragraph.", id: signpostID)
                    
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(returning: nil)
                }
            })
        }
    }
    
    public override func willSave() {
        self.feed?.objectWillChange.send()
    }
}
