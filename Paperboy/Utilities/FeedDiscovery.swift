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
import RegexBuilder
import os

class FeedDiscovery {

    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedDiscovery")
    
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

        Self.logger.info("Starting discovery for \(url.absoluteString).")
        
        var result: [DiscoveredFeed] = []
        
        // Try the first URL.
        Self.logger.info("Trying direct feed for \(url.absoluteString).")
        if let feed = try? await Self.parsedFeed(for: url).get() {
            let feed = Self.unwrapFeed(feed: feed)
            let model = FeedModel(from: feed, url: url, in: context)

            Self.logger.info("Direct feed found for \(url.absoluteString): \(model.normalisedTitle).")

            result.append(.init(feed: model, kind: .direct))
        }
        
        // Try to scan for a feed reference in HTML head.
        Self.logger.info("Scanning for feed references in HTML head for \(url.absoluteString).")
        do {
            let html = try String(contentsOf: url)
            let document = try SwiftSoup.parse(html)
            let feedURLs = try document.getElementsByTag("link").filter { element in
                let type = try? element.attr("type")
                
                // TODO: JSON.
                return type == "application/rss+xml" || type == "application/atom+xml"
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

            Self.logger.info("Found \(feedURLs.count) feed references in HTML head for \(url.absoluteString).")
            
            var count = 0

            for url in feedURLs {
                if let feed = try? await Self.parsedFeed(for: url).get() {
                    let feed = Self.unwrapFeed(feed: feed)
                    let model = FeedModel(from: feed, url: url, in: context)
                    result.append(.init(feed: model, kind: .direct))
                    count += 1
                }
            }

            Self.logger.info("Found \(count) valid feed references in HTML head for \(url.absoluteString).")
        } catch {
            Self.logger.warning("Exception while scanning for feed references in HTML head for \(url.absoluteString): \(error.localizedDescription)")
        }
        
        // Try to add https in front of URL if necessary.
        if !(url.scheme?.starts(with: "http") ?? false) {

            Self.logger.info("Feed URL doesn't use HTTP/HTTPS, trying to add https in front of it for \(url.absoluteString).")

            var components = URLComponents(string: String(url.absoluteString.split(separator: "//").last!))
            components?.scheme = "https"
            
            if let url = components?.url {
                print(url)
                let results = await start(for: url, in: context)

                Self.logger.info("Found \(results.count) feeds in https version of \(url.absoluteString).")

                result.append(contentsOf: results)
            }
        }
        
        return result
    }
    
    static private func parsedFeed(for url: URL) async -> Result<Feed, ParserError> {

        Self.logger.info("Parsing feed for \(url.absoluteString).")

        guard let (data, response) = try? await URLSession.shared.data(from: url) else {
            Self.logger.warning("Error while fetching data from \(url.absoluteString).")
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
        case .atom(let atom):
            return atom
        case .json(_):
            Self.logger.warning("JSON feed found, not supported.")
            return RSSFeed()
        case .rss(let rss):
            return rss
        }
    }
}
