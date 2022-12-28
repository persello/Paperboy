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

extension FeedModel {

    static var logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "FeedModel")
    
    // MARK: Internal data types.
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

        static func build(timeFrame: TimeFrame, items: [FeedItemModel]) -> [GroupedFeedItems] {
            var groupedItems: [GroupedFeedItems] = []

            FeedModel.logger.info("Building grouped items with time frame \(timeFrame.rawValue) from \(items.count) items.")

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

            FeedModel.logger.info("Built \(groupedItems.count) groups. Setting titles...")

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

            FeedModel.logger.info("Titles set. Sorting groups...")

            // Sort groups.
            groupedItems.sort(by: { $0.referenceDate > $1.referenceDate })

            FeedModel.logger.info("Groups sorted. Sorting items...")

            // Sort items inside groups.
            for index in 0..<groupedItems.count {
                groupedItems[index].items.sort(by: { $0.publicationDate! > $1.publicationDate! })
            }

            return groupedItems
        }
    }
    
    // MARK: Initialisers.
    convenience init(_ copy: FeedModel, in context: NSManagedObjectContext) {
        self.init(context: context)
        
        self.title = copy.title
        self.url = copy.url
        
        Self.logger.info("Initialised \"\(self.normalisedTitle)\" [\(self.url?.absoluteString ?? "no URL")] from copy.")
        
        Task {
            try await self.refresh()
        }
    }
    
    convenience init(from feed: FeedProtocol, url: URL, in context: NSManagedObjectContext) {
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
        
        DispatchQueue.main.async {
            self.status = status.rawValue
            try? self.managedObjectContext?.save()
        }
    }
    
    private func getInternalFeed() async throws -> (any FeedProtocol) {
        
        Self.logger.info("Getting internal feed for \"\(self.normalisedTitle)\".")
        
        guard let url = self.url else {
            Self.logger.error("Cannot get internal feed, because the feed model  for \"\(self.normalisedTitle)\" does not have an URL.")
            throw Error.modelDoesNotContainURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)

        return try await withCheckedThrowingContinuation({ continuation in
            let parser = FeedParser(data: data)
            
            Self.logger.info("Parsing feed for \"\(self.normalisedTitle)\".")
            
            parser.parseAsync(queue: DispatchQueue.global(qos: .userInitiated), result: { groups in
                switch groups {
                case .success(let success):
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
        
        Self.logger.info("Refreshing icon for \"\(self.normalisedTitle)\".")
        
        let feed = try await self.getInternalFeed()
        
        if let iconURL = feed.iconURL,
           let source = CGImageSourceCreateWithURL(iconURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) {

            Self.logger.info("Getting icon from URL \(iconURL.absoluteString) for \"\(self.normalisedTitle)\".")

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
                
                Self.logger.info("Created icon thumbnail from URL for \"\(self.normalisedTitle)\".")

                DispatchQueue.main.async {
                    self.icon = data
                }
            } else {
                Self.logger.warning("Could not create icon thumbnail from URL for \"\(self.normalisedTitle)\".")
            }
        } else if let url = feed.websiteURL {

            // Try to get the icon from the linked website's favicon.
            Self.logger.info("Getting favicon from website URL \(url.absoluteString) for \"\(self.normalisedTitle)\".")

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

        Self.logger.info("Refreshing feed \"\(self.normalisedTitle)\".")

        DispatchQueue.main.async {
            self.setStatus(.refreshing)
        }
        
        defer {
            DispatchQueue.main.async {
                self.setStatus(.idle)
            }
        }
        
        guard let context = self.managedObjectContext else {
            Self.logger.error("Cannot refresh feed, because the feed model for \"\(self.normalisedTitle)\" does not have a managed object context.")
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

        Self.logger.info("Found \(itemSet.count) new items for \"\(self.normalisedTitle)\".")
        
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
    
    var itemsToRead: Int {
        guard let context = self.managedObjectContext else {
            Self.logger.warning("Cannot get number of unread items for feed \"\(self.normalisedTitle)\", because the feed model does not have a managed object context.")
            return 0
        }
        
        let request = FeedItemModel.fetchRequest()
        request.entity = NSEntityDescription.entity(forEntityName: "FeedItemModel", in: context)
        request.predicate = NSPredicate(format: "feed == %@ AND read == NO", self)
        
        let items = try? context.fetch(request)
        
        return items?.count ?? 0
    }

    var groupedItems: [GroupedFeedItems] {
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
