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

extension FeedModel {
    
    func refresh(onlyAfter interval: TimeInterval) {
        // TODO: Implement.
    }
    
    func refresh() throws {
        guard let url = self.url,
              let context = self.managedObjectContext else {
            
            // TODO: Errors.
            
            return
        }
        
        let parser = FeedParser(URL: url)
        parser.parseAsync(queue: DispatchQueue.global(qos: .userInitiated), result: { result in
            
            guard let feed = try? result.get().rssFeed else {
                return
            }
            
            // Items
            let itemSet: Set<FeedItemModel> = feed.fetchItems()
                .filter({ item in
                    !self.items!.contains(where: { existingItem in
                        guard let existingItemModel = existingItem as? FeedItemModel else {
                            return false
                        }
                        
                        return existingItemModel.link == item.url
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
            if let iconURL = feed.iconURL,
               let source = CGImageSourceCreateWithURL(iconURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) {
                
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
            }
            
            DispatchQueue.main.async {
                try? context.save()
            }
        })
    }
    
    var iconImage: CGImage? {
        if let data = self.icon,
           let source = CGImageSourceCreateWithData(data as CFData, [:] as CFDictionary) {
            let image = CGImageSourceCreateImageAtIndex(source, 0, [:] as CFDictionary)
            return image
        } else {
            return nil
        }
    }
}
