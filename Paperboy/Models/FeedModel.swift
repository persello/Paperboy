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
    
    enum Status: Int16 {
        case idle = 0
        case refreshing = 1
        case error = 2
    }
    
    convenience init(_ copy: FeedModel, in context: NSManagedObjectContext) {
        self.init(context: context)
        
        self.title = copy.title
        self.url = copy.url
        
        Task {
            await self.refresh()
        }
    }
    
    convenience init(from feed: FeedProtocol, url: URL, in context: NSManagedObjectContext) {
        self.init(context: context)
        
        self.title = feed.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.url = url
        
        Task {
            await self.refresh()
        }
    }
    
    private func setStatus(_ status: Status) {
        self.status = status.rawValue
    }
    
    func refresh(onlyAfter interval: TimeInterval) {
        // TODO: Implement.
    }
    
    func refresh() async {
        DispatchQueue.main.async {
            self.setStatus(.refreshing)
        }
        
        guard let context = self.managedObjectContext else {
            
            // TODO: Errors.
            return
        }
        
        guard let feed = await self.getInternalFeed() else {
            return
        }
        
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
        await self.refreshIcon()
        
        DispatchQueue.main.async {
            
            // TODO: Error management.
            try? context.save()
            self.setStatus(.idle)
            
            // TODO: Error status.
        }
    }
    
    private func getInternalFeed() async -> (any FeedProtocol)? {
        guard let url = self.url,
              let (data, _) = try? await URLSession.shared.data(from: url) else {
            return nil
        }

        return await withCheckedContinuation({ continuation in
            let parser = FeedParser(data: data)
            parser.parseAsync(queue: DispatchQueue.global(qos: .userInitiated), result: { result in
                if let feed = try? result.get().rssFeed {
                    continuation.resume(returning: feed)
                } else if let feed = try? result.get().atomFeed {
                    continuation.resume(returning: feed)
                } else {
                    // TODO: Error management.
                    continuation.resume(returning: nil)
                }
            })
        })
    }
    
    private func refreshIcon() async {
        guard let feed = await self.getInternalFeed() else {
            return
        }
        
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
    
    var iconImage: CGImage? {
        if let data = self.icon,
           let source = CGImageSourceCreateWithData(data as CFData, [:] as CFDictionary) {
            let image = CGImageSourceCreateImageAtIndex(source, 0, [:] as CFDictionary)
            return image
        } else {
            Task {
                await self.refreshIcon()
            }
            return nil
        }
    }
}
