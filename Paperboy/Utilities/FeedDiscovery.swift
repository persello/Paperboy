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
    
    class DiscoveredFeed: Hashable, Identifiable, ObservableObject, Equatable {
        @Published var feed: FeedModel
        var kind: FeedDiscoveryKind
        
        init(feed: FeedModel, kind: FeedDiscoveryKind) {
            self.feed = feed
            self.kind = kind
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(feed)
        }
        
        var id: String {
            return feed.url.absoluteString
        }
        
        static func == (lhs: FeedDiscovery.DiscoveredFeed, rhs: FeedDiscovery.DiscoveredFeed) -> Bool {
            lhs.feed.url == rhs.feed.url
        }
    }
    
    static private func normaliseURL(url: URL, host: String) -> URL? {
        
        let pathRegex = /(http[s]?:\/\/)?([^\/\s]+\/)?(.*)/
        let match = url.absoluteString.appending("/").matches(of: pathRegex).first
        
        if let path = match?.output.3 {
            var components = URLComponents()
            components.scheme = "https"
            components.host = host
            components.path = String("/\(path.trimmingCharacters(in: .init(arrayLiteral: "/")))")
            
            return components.url
        }
        
        return nil
    }
    
    static func start(for inputURL: URL, in context: NSManagedObjectContext, recursionDepth: Int = 0) -> AsyncStream<DiscoveredFeed> {
        AsyncStream { continuation in
            Task {
                if recursionDepth > 2 {
                    continuation.finish()
                    return
                }
                
                Self.logger.info("Starting discovery for \(inputURL.absoluteString).")
                
                let absoluteString = String(inputURL.absoluteString.trimmingPrefix("feed:"))
                
                var URLsFromLinks: [URL] = []
                let host = absoluteString.trimmingPrefix("https://").components(separatedBy: "/").first ?? absoluteString
                
                guard let url = normaliseURL(url: inputURL, host: host) else {
                    Self.logger.info("Cannot normalise url \(inputURL.absoluteString).")
                    continuation.finish()
                    return
                }
                
                // Try the first URL.
                Self.logger.info("Trying direct feed for \(url.absoluteString).")

                if let model = try? await FeedModel(url: url) {
                    Self.logger.info("Direct feed found for \(url.absoluteString): \(model.title).")
                    continuation.yield(.init(feed: model, kind: .direct))
                }
                
                // Try to scan for a feed reference in HTML head.
                Self.logger.info("Scanning for feed references in HTML head for \(url.absoluteString).")
                do {
                    let (data, _) = try await URLSession.shared.data(from: url, delegate: FeedDiscoveryTaskDelegate())
                    let html = String(decoding: data, as: UTF8.self)
                    let document = try SwiftSoup.parse(html)
                    var feedURLs = try document.getElementsByTag("link").filter { element in
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
                    
                    // URLs from links.
                    URLsFromLinks = try document.getElementsByTag("a").compactMap({ element in
                        try? element.attr("href")
                    }).filter({ link in
                        return link.contains("rss") || link.contains("feed") || link.contains("atom")
                    }).compactMap({ link in
                        return URL(string: link)
                    })
                    
                    feedURLs.append(contentsOf: URLsFromLinks)
                    
                    Self.logger.info("Found \(feedURLs.count) feed references in HTML head for \(url.absoluteString).")
                    
                    var count = 0
                    
                    for url in feedURLs {
                        if let feed = try? await Self.parsedFeed(for: url).get() {
                            let feed = Self.unwrapFeed(feed: feed)
                            let model = try await FeedModel(url: url)
                            continuation.yield(.init(feed: model, kind: .direct))
                            count += 1
                        }
                    }
                    
                    Self.logger.info("Found \(count) valid feed references in HTML head for \(url.absoluteString).")
                } catch {
                    Self.logger.warning("Exception while scanning for feed references in HTML head for \(url.absoluteString): \(error.localizedDescription)")
                }
                
                // Repeat search recursively for all the found additional URLs.
                for url in URLsFromLinks {
                    Self.logger.info("Trying to search again inside \(URLsFromLinks.count) found URLs.")
                    
                    if let normalisedURL = normaliseURL(url: url, host: host) {
                        
                        for await item in Self.start(for: normalisedURL, in: context, recursionDepth: recursionDepth + 1) {
                            continuation.yield(item)
                        }
                    }
                }
                
                continuation.finish()
            }
        }
    }
    
    static private func parsedFeed(for url: URL) async -> Result<Feed, ParserError> {
        
        Self.logger.info("Parsing feed for \(url.absoluteString).")
        
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
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

class FeedDiscoveryTaskDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
        if request.url?.scheme?.starts(with: "https") ?? false {
            return request
        } else {
            return nil
        }
    }
}
