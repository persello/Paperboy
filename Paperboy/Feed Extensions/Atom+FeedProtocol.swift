//
//  Atom+FeedProtocol.swift
//  Paperboy
//
//  Created by Riccardo Persello on 23/12/22.
//

import Foundation
import FeedKit

extension AtomFeed: FeedProtocol {
    
    public var description: String? {
        return self.subtitle?.value
    }
    
    public var iconURL: URL? {
        guard let link = self.icon else {
            return nil
        }
        
        return URL(string: link)
    }
    
    public var websiteURL: URL? {
        let link = self.links?.filter({ link in
            link.attributes?.type == "text/html" && link.attributes?.rel == "alternate"
        }).first?.attributes?.href
        
        if let link {
            return URL(string: link)
        }
        
        return nil
    }
    
    public func fetchItems() -> [FeedItemProtocol] {
        return self.entries ?? []
    }
}
