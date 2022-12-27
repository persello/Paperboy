//
//  FeedModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 08/12/22.
//

import Foundation
import FeedKit
import CoreData
import CoreGraphics
import ImageIO
import CoreImage
import FaviconFinder

extension FeedModel {
    
    // MARK: Internal data types.
    enum Status: Int16 {
        case idle = 0
        case refreshing = 1
        case error = 2
    }
    
    enum Error: LocalizedError {
        case modelDoesNotContainURL
        case modelDoesNotContainMOC
        case unsupportedFeedFormat(String)
        
        var errorDescription: String? {
            switch self {
            case .modelDoesNotContainURL:
                return NSLocalizedString("The feed does not contain a URL.", comment: "FeedModel error")
            case .modelDoesNotContainMOC:
                return NSLocalizedString("The feed does not have a Core Data managed object context.", comment: "FeedModel error")
            case .unsupportedFeedFormat(let format):
                return NSLocalizedString("The feed format \"\(format)\" is not supported.", comment: "FeedModel error")
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .modelDoesNotContainURL,
                 .modelDoesNotContainMOC:
                return NSLocalizedString("You'll need to delete this feed and create it again.", comment: "FeedModel error")
            case .unsupportedFeedFormat(_):
                return NSLocalizedString("Search for a feed that uses a different format.", comment: "FeedModel error")
            }
        }
    }
    
    // MARK: Initialisers.
    convenience init(_ copy: FeedModel, in context: NSManagedObjectContext) {
        self.init(context: context)
        
        self.title = copy.title
        self.url = copy.url
        
        Task {
            try await self.refresh()
        }
    }
    
    convenience init(from feed: FeedProtocol, url: URL, in context: NSManagedObjectContext) {
        self.init(context: context)
        
        self.title = feed.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.url = url
        
        Task {
            try await self.refresh()
        }
    }
    
    // MARK: Private functions.
    func setStatus(_ status: Status) {
        
        // TODO: Error handling.
        
        DispatchQueue.main.async {
            self.status = status.rawValue
            try? self.managedObjectContext?.save()
        }
    }
    
    private func getInternalFeed() async throws -> (any FeedProtocol) {
        guard let url = self.url else {
            throw Error.modelDoesNotContainURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)

        return try await withCheckedThrowingContinuation({ continuation in
            let parser = FeedParser(data: data)
            parser.parseAsync(queue: DispatchQueue.global(qos: .userInitiated), result: { result in
                switch result {
                case .success(let success):
                    switch success {
                    case .atom(let atom):
                        continuation.resume(returning: atom)
                    case .rss(let rss):
                        continuation.resume(returning: rss)
                    case .json(_):
                        continuation.resume(throwing: Error.unsupportedFeedFormat("JSON"))
                    }
                case .failure(let failure):
                    continuation.resume(throwing: failure)
                }
            })
        })
    }
    
    private func refreshIcon() async throws {
        let feed = try await self.getInternalFeed()
        
        if let iconURL = feed.iconURL,
           let source = CGImageSourceCreateWithURL(iconURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) {
            
            // Get the feed's icon from the specified URL.
            
            let targetSize = 64
            let thumbnailOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceShouldCacheImmediately: true,
                                             kCGImageSourceThumbnailMaxPixelSize: targetSize] as CFDictionary
            
            if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) {
                let context = CIContext()
                let image = CIImage(cgImage: thumbnail)
                let data = context.jpegRepresentation(of: image, colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!)
                
                DispatchQueue.main.async {
                    self.icon = data
                }
            }
        } else if let url = feed.websiteURL {
            // Try to get the icon from the linked website's favicon.
            Task {
                let finder = FaviconFinder(url: url)
                let icon = try? await finder.downloadFavicon()
                
                DispatchQueue.main.async {
                    self.icon = icon?.data
                }
            }
            
        }
    }
    
    // MARK: Public functions.
    func refresh(onlyAfter interval: TimeInterval) async throws {
        guard let lastRefresh else {
            try await refresh()
            return
        }
        
        if lastRefresh + interval < Date.now {
            try await refresh()
        }
    }
    
    func refresh() async throws {
        DispatchQueue.main.async {
            self.setStatus(.refreshing)
        }
        
        defer {
            DispatchQueue.main.async {
                self.setStatus(.idle)
            }
        }
        
        guard let context = self.managedObjectContext else {
            throw Error.modelDoesNotContainMOC
        }
        
        let feed = try await self.getInternalFeed()
        
        // Items
        let itemSet: Set<FeedItemModel> = feed.fetchItems()
            .filter({ item in
                !self.items!.contains(where: { existingItem in
                    guard let existingItemModel = existingItem as? FeedItemModel else {
                        return false
                    }
                    
                    return existingItemModel.url == item.url
                })
            }).map({
                FeedItemModel(from: $0, context: context)
            }).reduce(into: Set()) { partialResult, item in
                partialResult.insert(item)
            }
        
        DispatchQueue.main.async {
            self.addToItems(NSSet(set: itemSet))
        }
        
        // Icon
        try await self.refreshIcon()
        
        DispatchQueue.main.async {
            
            self.lastRefresh = Date.now
            
            // TODO: Error management.
            try? context.save()
        }
    }
    
    func markAllAsRead() {
        guard let set = self.items,
              let items = Array(set) as? Array<FeedItemModel> else {
            return
        }
        
        for item in items {
            item.read = true
        }
        
        try? self.managedObjectContext?.save()
    }
    
    // MARK: Computed variables.
    var iconImage: CGImage? {
        if let data = self.icon,
           let source = CGImageSourceCreateWithData(data as CFData, [:] as CFDictionary) {
            let image = CGImageSourceCreateImageAtIndex(source, 0, [:] as CFDictionary)
            return image
        } else {
            Task {
                try? await self.refreshIcon()
            }
            return nil
        }
    }
    
    var normalisedTitle: String {
        return self.title ?? "Unnamed feed"
    }
    
    var itemsToRead: Int {
        guard let context = self.managedObjectContext else {
            return 0
        }
        
        let request = FeedItemModel.fetchRequest()
        request.entity = NSEntityDescription.entity(forEntityName: "FeedItemModel", in: context)
        request.predicate = NSPredicate(format: "feed == %@ AND read == NO", self)
        
        let items = try? context.fetch(request)
        
        return items?.count ?? 0
    }
    
    var groupedItems: [(Date?, [FeedItemModel])] {
        guard let items = items as? Set<FeedItemModel> else { return [] }
        var result: [(Date?, [FeedItemModel])] = []
        
        for item in items {
            var calendarDate: Date? = nil
            if let date = item.publicationDate {
                let dateComponents = Calendar.current.dateComponents([.day, .month, .year], from: date)
                calendarDate = Calendar.current.date(from: dateComponents)
            }
            
            // Search for an existing group.
            if let groupIndex = result.firstIndex(where: { $0.0 == calendarDate }) {
                result[groupIndex].1.append(item)
            } else {
                result.append((calendarDate, [item]))
            }
        }
        
        // Sort groups and items. Newest first, groups without date last.
        result.sort(by: { lhs, rhs in
            if let lhsDate = lhs.0,
               let rhsDate = rhs.0 {
                return lhsDate > rhsDate
            } else {
                return lhs.0 != nil
            }
        })

        result = result.map({ (date, items) in
            return (date, items.sorted(by: { lhs, rhs in
                if let lhsDate = lhs.publicationDate,
                   let rhsDate = rhs.publicationDate {
                    return lhsDate > rhsDate
                } else {
                    return lhs.publicationDate != nil
                }
            }))
        })


        return result
    }
}
