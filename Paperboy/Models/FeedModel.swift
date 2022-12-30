//
//  FeedModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 08/12/22.
//

import Foundation
import FeedKit
import CoreData
import CoreImage
import FaviconFinder
import os

#if os(iOS)
import UIKit
#endif

extension FeedModel {

    static var logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedModel")
    static var signposter: OSSignposter = OSSignposter(logger: logger)
    static var cache: NSCache = NSCache<FeedModel, FeedCacheWrapper>()
    
    // MARK: Internal data types.
    class FeedCacheWrapper: NSObject {
        let feed: FeedKit.Feed
        
        init(_ value: Feed) {
            self.feed = value
        }
    }
    
    enum Status: Int16, CustomStringConvertible {
        case idle = 0
        case refreshing = 1
        case error = 2
        
        var description: String {
            switch self {
            case .idle: return "idle"
            case .refreshing: return "refreshing"
            case .error: return "error"
            }
        }
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
    
    struct GroupedFeedItems: Identifiable {
        enum TimeFrame: String {
            case day, month, year, all
        }

        var title: String?
        let referenceDate: Date
        let timeFrame: TimeFrame
        var items: [FeedItemModel]
        let id = UUID()
        
        static var logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "GroupedFeedItems")
        static var signposter: OSSignposter = OSSignposter(logger: logger)
        
        static func build(timeFrame: TimeFrame, items: [FeedItemModel]) -> [GroupedFeedItems] {
            
            let signpostID = Self.signposter.makeSignpostID()
            let state = Self.signposter.beginInterval("build", id: signpostID, "\(items.count) items.")
            
            defer {
                Self.signposter.endInterval("build", state)
            }
            
            var groupedItems: [GroupedFeedItems] = []

            Self.logger.info("Building grouped items with time frame \(timeFrame.rawValue) from \(items.count) items.")

            let calendar = Calendar.current
            let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
            
            for item in items {
                let itemDate = calendar.dateComponents(components, from: item.publicationDate!)
                let referenceDate: Date

                switch timeFrame {
                case .day:
                    referenceDate = calendar.date(from: DateComponents(year: itemDate.year, month: itemDate.month, day: itemDate.day))!
                case .month:
                    referenceDate = calendar.date(from: DateComponents(year: itemDate.year, month: itemDate.month))!
                case .year:
                    referenceDate = calendar.date(from: DateComponents(year: itemDate.year))!
                case .all:
                    referenceDate = item.publicationDate!
                }

                if let index = groupedItems.firstIndex(where: { $0.referenceDate == referenceDate }) {
                    groupedItems[index].items.append(item)
                } else {
                    groupedItems.append(GroupedFeedItems(title: nil, referenceDate: referenceDate, timeFrame: timeFrame, items: [item]))
                }
            }

            Self.signposter.emitEvent("Groups built.", id: signpostID, "\(groupedItems.count) groups.")
            Self.logger.info("Built \(groupedItems.count) groups. Setting titles...")

            // Set titles.
            let dateFormatter: DateFormatter = DateFormatter()
            for index in 0..<groupedItems.count {
                let item = groupedItems[index]

                // Choose date format dynamically.
                switch timeFrame {
                case .day:
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.doesRelativeDateFormatting = true
                    dateFormatter.dateStyle = .long

                    groupedItems[index].title = dateFormatter.string(from: item.referenceDate)
                case .month:
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.dateFormat = "MMMM yyyy"

                    groupedItems[index].title = dateFormatter.string(from: item.referenceDate)
                case .year:
                    dateFormatter.locale = NSLocale.current
                    dateFormatter.dateFormat = "yyyy"

                    groupedItems[index].title = dateFormatter.string(from: item.referenceDate)
                case .all:
                    groupedItems[index].title = NSLocalizedString("All articles", comment: "FeedModel grouped items title")
                }
            }
            
            Self.signposter.emitEvent("Groups named.", id: signpostID)
            Self.logger.info("Titles set. Sorting groups...")

            // Sort groups.
            groupedItems.sort(by: { $0.referenceDate > $1.referenceDate })
            
            Self.signposter.emitEvent("Groups sorted.", id: signpostID)
            Self.logger.info("Groups sorted. Sorting items...")

            // Sort items inside groups.
            for index in 0..<groupedItems.count {
                groupedItems[index].items.sort(by: { $0.publicationDate! > $1.publicationDate! })
            }
            
            Self.signposter.emitEvent("Items sorted inside groups.")
            
            return groupedItems
        }
    }
    
    // MARK: Initialisers.
    convenience init(_ copy: FeedModel, in context: NSManagedObjectContext) {
        
        let signpostID = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval("initFromCopy", id: signpostID, "\(copy.normalisedTitle)")
        
        defer {
            Self.signposter.endInterval("initFromCopy", state)
        }
        
        self.init(context: context)
        
        self.title = copy.title
        self.url = copy.url
        
        Self.logger.info("Initialised \"\(self.normalisedTitle)\" [\(self.url?.absoluteString ?? "no URL")] from copy.")
        
        Task {
            try await self.refresh()
        }
    }
    
    convenience init(from feed: any FeedProtocol, url: URL, in context: NSManagedObjectContext) {
        
        let signpostID = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval("initFromFeedProtocol", id: signpostID, "\(feed.title ?? "Unnamed FeedProtocol")")
        
        defer {
            Self.signposter.endInterval("initFromFeedProtocol", state)
        }
        
        self.init(context: context)
        
        self.title = feed.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.url = url
        
        Self.logger.info("Initialised \"\(self.normalisedTitle)\" [\(self.url?.absoluteString ?? "no URL")] from FeedProtocol.")
        
        Task {
            try await self.refresh()
        }
    }
    
    // MARK: Private functions.
    func setStatus(_ status: Status) {
        
        // TODO: Error handling.
        
        Self.logger.info("Setting feed status for \"\(self.normalisedTitle)\" to \(self.status).")
        
        #if os(iOS)
        UIApplication.shared.isNetworkActivityIndicatorVisible = (status == .refreshing)
        #endif
        
        DispatchQueue.main.async {
            self.status = status.rawValue
            try? self.managedObjectContext?.save()
        }
    }
    
    private func getInternalFeed(cached: Bool) async throws -> (any FeedProtocol) {
        
        let signpostID = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval("getInternalFeed", id: signpostID, "\(self.normalisedTitle)")
        
        defer {
            Self.signposter.endInterval("getInternalFeed", state)
        }
        
        if cached {
            if let cachedFeed = Self.cache.object(forKey: self) {
                Self.signposter.emitEvent("Got feed from cache.", id: signpostID)
                
                switch cachedFeed.feed {
                case .atom(let atom):
                    return atom
                case .rss(let rss):
                    return rss
                case .json(_):
                    Self.logger.warning("Unsupported JSON feed found in cache for \"\(self.normalisedTitle)\".")
                    throw Error.unsupportedFeedFormat("JSON")
                }
            }
        }
        
        Self.logger.info("Getting internal feed for \"\(self.normalisedTitle)\".")
        
        guard let url = self.url else {
            Self.logger.error("Cannot get internal feed, because the feed model  for \"\(self.normalisedTitle)\" does not have an URL.")
            throw Error.modelDoesNotContainURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        Self.signposter.emitEvent("Data fetched.", id: signpostID, "\(data.count) bytes.")

        return try await withCheckedThrowingContinuation({ continuation in
            let parser = FeedParser(data: data)
            
            Self.logger.info("Parsing feed for \"\(self.normalisedTitle)\".")
            Self.signposter.emitEvent("Starting feed parser.", id: signpostID)
            
            parser.parseAsync(queue: DispatchQueue.global(qos: .userInitiated), result: { groups in
                Self.signposter.emitEvent("Feed parsed.", id: signpostID)
                
                switch groups {
                case .success(let success):
                    
                    Self.cache.setObject(FeedCacheWrapper(success), forKey: self)
                    
                    switch success {
                    case .atom(let atom):
                        continuation.resume(returning: atom)
                    case .rss(let rss):
                        continuation.resume(returning: rss)
                    case .json(_):
                        Self.logger.warning("Parser found an unsupported JSON feed for \"\(self.normalisedTitle)\".")
                        continuation.resume(throwing: Error.unsupportedFeedFormat("JSON"))
                    }
                case .failure(let failure):
                    Self.logger.error("An error occurred during feed parsing for \"\(self.normalisedTitle)\": \(failure.localizedDescription).")
                    continuation.resume(throwing: failure)
                }
            })
        })
    }
    
    private func refreshIcon() async throws {
        
        let signpostID = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval("refreshIcon", id: signpostID, "\(self.normalisedTitle)")
        
        defer {
            Self.signposter.endInterval("refreshIcon", state)
        }
        
        Self.logger.info("Refreshing icon for \"\(self.normalisedTitle)\".")
        
        let feed = try await self.getInternalFeed(cached: true)
        
        if let iconURL = feed.iconURL,
           let source = CGImageSourceCreateWithURL(iconURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) {
            
            Self.logger.info("Getting icon from URL \(iconURL.absoluteString) for \"\(self.normalisedTitle)\".")
            Self.signposter.emitEvent("Got icon from icon URL.", id: signpostID)

            // Get the feed's icon from the specified URL.
            
            let targetSize = 64
            let thumbnailOptions = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                      kCGImageSourceCreateThumbnailWithTransform: true,
                                            kCGImageSourceShouldCacheImmediately: true,
                                             kCGImageSourceThumbnailMaxPixelSize: targetSize] as CFDictionary
            
            if let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) {
                
                Self.signposter.emitEvent("Thumbnail created.", id: signpostID)
                
                let context = CIContext()
                let image = CIImage(cgImage: thumbnail)
                let data = context.jpegRepresentation(of: image, colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!)
                
                Self.signposter.emitEvent("JPEG created.", id: signpostID)
                
                Self.logger.info("Created icon thumbnail from URL for \"\(self.normalisedTitle)\".")

                DispatchQueue.main.async {
                    self.icon = data
                }
            } else {
                Self.logger.warning("Could not create icon thumbnail from URL for \"\(self.normalisedTitle)\".")
            }
        } else if let url = feed.websiteURL {

            // Try to get the icon from the linked website's favicon.
            Self.signposter.emitEvent("Getting icon from Website URL.", id: signpostID)
            Self.logger.info("Getting favicon from website URL \(url.absoluteString) for \"\(self.normalisedTitle)\".")
            
            Task {
                let finder = FaviconFinder(url: url)
                let icon = try? await finder.downloadFavicon()
                
                Self.signposter.emitEvent("Icon downloaded from website URL.", id: signpostID)
                
                DispatchQueue.main.async {
                    self.icon = icon?.data
                }
            }
            
        }
    }
    
    // MARK: Public functions.
    func refresh(onlyAfter interval: TimeInterval) async throws {

        Self.logger.info("Refreshing feed \"\(self.normalisedTitle)\" with minimum interval of \(interval) seconds.")

        guard let lastRefresh else {

            Self.logger.info("Feed \"\(self.normalisedTitle)\" has never been refreshed before, so refreshing now.")

            try await refresh()
            return
        }
        
        if lastRefresh + interval < Date.now {
            try await refresh()
        } else {
            Self.logger.info("Feed \"\(self.normalisedTitle)\" has been refreshed recently, so not refreshing now.")
        }
    }
    
    func refresh() async throws {
        
        let signpostID = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval("refresh", id: signpostID, "\(self.normalisedTitle)")
        
        defer {
            Self.signposter.endInterval("refresh", state)
            DispatchQueue.main.async {
                self.setStatus(.idle)
            }
        }

        Self.logger.info("Refreshing feed \"\(self.normalisedTitle)\".")

        DispatchQueue.main.async {
            self.setStatus(.refreshing)
        }
        
        guard let context = self.managedObjectContext else {
            Self.logger.error("Cannot refresh feed, because the feed model for \"\(self.normalisedTitle)\" does not have a managed object context.")
            throw Error.modelDoesNotContainMOC
        }
        
        let feed = try await self.getInternalFeed(cached: false)
        
        // Items
        let itemSet: Set<FeedItemModel> = feed.articles
            .filter({ item in
                !(self.items?.contains(where: { existingItem in
                    guard let existingItemModel = existingItem as? FeedItemModel else {
                        return false
                    }
                    
                    return existingItemModel.url == item.url
                }) ?? true)
            }).map({
                FeedItemModel(from: $0, context: context)
            }).reduce(into: Set()) { partialResult, item in
                partialResult.insert(item)
            }
        
        Self.signposter.emitEvent("New item models set created.", id: signpostID)

        Self.logger.info("Found \(itemSet.count) new items for \"\(self.normalisedTitle)\".")
        
        DispatchQueue.main.async {
            self.addToItems(NSSet(set: itemSet))
        }
        
        Self.signposter.emitEvent("Starting deduplication.", id: signpostID)
        
        // Deduplicate existing items by using URL, date and normalised title.
        // This is necessary because CloudKit does not support unique constraints.
        for item in self.items! {
            guard let itemModel = item as? FeedItemModel else {
                continue
            }
            
            let duplicates = self.items!.filter({ existingItem in
                guard let existingItemModel = existingItem as? FeedItemModel else {
                    return false
                }
                
                return existingItemModel.url == itemModel.url &&
                    existingItemModel.publicationDate == itemModel.publicationDate &&
                    existingItemModel.normalisedTitle == itemModel.normalisedTitle
            })
            
            if duplicates.count > 1 {
                Self.logger.info("Found \(duplicates.count) duplicates for item \"\(itemModel.normalisedTitle)\" in feed \"\(self.normalisedTitle)\".")
                
                for duplicate in duplicates {
                    guard let duplicateModel = duplicate as? FeedItemModel else {
                        continue
                    }
                    
                    if duplicateModel != itemModel {
                        Self.logger.info("Deleting duplicate item \"\(duplicateModel.normalisedTitle)\" in feed \"\(self.normalisedTitle)\".")
                        context.delete(duplicateModel)
                    }
                }
            }
        }
        
        Self.signposter.emitEvent("Deduplication finished.", id: signpostID)
        
        // Icon
        try await self.refreshIcon()
        
        DispatchQueue.main.async {
            
            self.lastRefresh = Date.now
            
            // TODO: Error management.
            try? context.save()
        }
    }
    
    func markAllAsRead() {

        Self.logger.info("Marking all items in feed \"\(self.normalisedTitle)\" as read.")

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

            Self.logger.info("Getting icon from data for \"\(self.normalisedTitle)\".")

            let image = CGImageSourceCreateImageAtIndex(source, 0, [:] as CFDictionary)
            return image
        } else {

            Self.logger.info("No icon data for \"\(self.normalisedTitle)\". Refreshing icon.")

            Task {
                try? await self.refreshIcon()
            }
            
            return nil
        }
    }
    
    var normalisedTitle: String {
        return self.title ?? "Unnamed feed"
    }
    
    var unreadCount: Int {
        
        let itemsToRead = self.value(forKey: "itemsToRead") as! [FeedItemModel]
        return itemsToRead.count
    }

    var groupedItems: [GroupedFeedItems] {
        
        let signpostID = Self.signposter.makeSignpostID()
        let state = Self.signposter.beginInterval("groupedItems", id: signpostID, "\(self.normalisedTitle)")
        
        defer {
            Self.signposter.endInterval("groupedItems", state)
        }
        
        Self.logger.info("Grouping items for \"\(self.normalisedTitle)\".")

        // Calculate the average time between items.
        // If you publish feed items without a date, spiaze.
        guard let items = (self.items as? Set<FeedItemModel>)?
            .filter({ item in
                item.publicationDate != nil
            }),
              let firstItem = items.sorted(by: { $0.publicationDate! < $1.publicationDate! }).first,
              let lastItem = items.sorted(by: { $0.publicationDate! > $1.publicationDate! }).first else {

            Self.logger.info("No dated items for \"\(self.normalisedTitle)\".")
            return []
        }
        
        Self.signposter.emitEvent("Itemd filtered.")

        let timeBetweenItems = lastItem.publicationDate!.timeIntervalSince(firstItem.publicationDate!) / Double(items.count)

        Self.logger.info("Average time between items for \"\(self.normalisedTitle)\" is \(timeBetweenItems) seconds.")

        // Choose time frame for grouping.
        let timeFrame: GroupedFeedItems.TimeFrame

        // More than three items per...
        if timeBetweenItems < 60 * 60 * 24 / 3 {
            // ...day.
            timeFrame = .day
        } else if timeBetweenItems < 60 * 60 * 24 * 30 / 3 {
            // ...month.
            timeFrame = .month
        } else if timeBetweenItems < 60 * 60 * 24 * 365 / 3 {
            // ...year.
            timeFrame = .year
        } else {
            // ...all time.
            timeFrame = .all
        }

        Self.logger.info("Time frame for grouping items for \"\(self.normalisedTitle)\" is \(timeFrame.rawValue).")

        // Group items.
        let groupedItems = GroupedFeedItems.build(timeFrame: timeFrame, items: Array(items))
        
        return groupedItems
    }
}
