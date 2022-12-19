//
//  FeedDiscovery.swift
//  Paperboy
//
//  Created by Riccardo Persello on 17/12/22.
//

import Foundation
import FeedKit
import SwiftSoup
import CoreData

class FeedDiscovery {
    
    enum FeedDiscoveryKind {
        case direct
        case byHTMLLink
    }
    
    class DiscoveredFeed: Hashable, Identifiable, ObservableObject {
        @Published var feed: FeedModel
        var kind: FeedDiscoveryKind
        
        init(feed: FeedModel, kind: FeedDiscoveryKind) {
            self.feed = feed
            self.kind = kind
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(feed)
        }
        
        var id: FeedModel {
            return feed
        }
        
        static func == (lhs: FeedDiscovery.DiscoveredFeed, rhs: FeedDiscovery.DiscoveredFeed) -> Bool {
            lhs.feed == rhs.feed
        }
    }
    
    static func start(for url: URL, in context: NSManagedObjectContext) async -> [DiscoveredFeed] {
        
        var result: [DiscoveredFeed] = []
        
        // Try the first URL.
        if let feed = try? await Self.parsedFeed(for: url).get(){
            let feed = Self.unwrapFeed(feed: feed)
            let model = FeedModel(from: feed, url: url, in: context)
            result.append(.init(feed: model, kind: .direct))
        }
        
        // Try to scan for a feed link in HTML body.
        do {
            let html = try String(contentsOf: url)
            let document = try SwiftSoup.parse(html)
            let feedURLs = try document.getElementsByTag("link").filter { element in
                let rel = try? element.attr("rel")
                let type = try? element.attr("type")
                
                // TODO: Atom, JSON.
                return rel == "alternate" && type == "application/rss+xml"
            }.compactMap({ element in
                try? element.attr("href")
            }).compactMap({ link in
                // The link might be relative or absolute.
                if link.hasPrefix("http") {
                    return URL(string: link)
                } else {
                    return URL(string: link, relativeTo: url)
                }
            })
            
            for url in feedURLs {
                if let feed = try? await Self.parsedFeed(for: url).get() {
                    let feed = Self.unwrapFeed(feed: feed)
                    let model = FeedModel(from: feed, url: url, in: context)
                    result.append(.init(feed: model, kind: .direct))
                }
            }
        } catch {
            
        }
        
        // Try to add https in front of URL if necessary.
        if !(url.scheme?.starts(with: "http") ?? false) {
            
            // Ignore potential multiple schemes.
            if let pathOnly = url.absoluteString.split(separator: ":").last?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) {
                var components = URLComponents(string: String(pathOnly))
                components?.scheme = "https"
                
                if let url = components?.url {
                    result += await start(for: url, in: context)
                }
            }
        }
        
        return result
    }
    
    static private func parsedFeed(for url: URL) async -> Result<Feed, ParserError> {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            return .failure(ParserError.feedNotFound)
        }
        
        return await withCheckedContinuation({ continuation in
            let parser = FeedParser(data: data)
            parser.parseAsync { result in
                continuation.resume(returning: result)
            }
        })
    }
    
    static private func unwrapFeed(feed: Feed) -> any FeedProtocol {
        switch feed {
        case .atom(_):
            return RSSFeed()
        case .json(_):
            return RSSFeed()
        case .rss(let rss):
            return rss
        }
    }
}
