//
//  FeedItemModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 11/06/23.
//
//

import Foundation
import SwiftData
import SwiftSoup
import os

enum FeedItemModelError: Error {
    case noURL
}

@Model final public class FeedItemModel {
    var articleDescription: String?
    var publicationDate: Date?
    var read: Bool = false
    var title: String
    var url: URL
    var wallpaperURL: URL?
    var feed: FeedModel
    
    // MARK: Initialisers.
    init(title: String, url: URL, feed: FeedModel, articleDescription: String? = nil, publicationDate: Date? = nil, read: Bool = false, wallpaperURL: URL? = nil) {
        self.articleDescription = articleDescription
        self.publicationDate = publicationDate
        self.read = read
        self.title = title
        self.url = url
        self.wallpaperURL = wallpaperURL
        self.feed = feed
    }
    
    init<F: FeedItemProtocol>(from item: F) throws {
        guard let url = item.url else {
            throw FeedItemModelError.noURL
        }
        
        self.articleDescription = item.description
        self.url = url
        self.publicationDate = item.publicationDate
        self.title = item.title ?? "Untitled article"
    }
}

extension FeedItemModel {

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedItemModel")
    static let signposter = OSSignposter(logger: logger)
    
    // MARK: Public functions.
    public func updateWallpaper() {
        
        let signpostID = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval("updateWallpaper", id: signpostID, "\(self.title)")
        
        defer {
            Self.signposter.endInterval("updateWallpaper", state)
        }
        
        guard wallpaperURL == nil else {
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            
            Self.signposter.emitEvent("Getting article description.", id: signpostID)
            Self.logger.info("Fetching wallpaper for \"\(self.title)\" from article description.")

            guard let description = self.articleDescription else {
                Self.logger.info("No description for \"\(self.title)\".")
                return
            }
            
            Self.signposter.emitEvent("Starting HTML parser.", id: signpostID)
            
            let document = try? SwiftSoup.parse(description)
            let image = try? document?.select("img").first()
            guard let src = try? image?.attr("src") else {
                Self.logger.info("No image found in description of \"\(self.title)\".")
                return
            }

            DispatchQueue.main.async {
                self.wallpaperURL = URL(string: src)
            }
        }
    }
    
    // MARK: Computed properties.
    var normalisedContentDescription: String? {
        get async {
            
            let signpostID = Self.signposter.makeSignpostID()
            let state = Self.signposter.beginInterval("normalisedContentDescription", id: signpostID, "\(self.title)")
            
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
}
