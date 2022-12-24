//
//  Atom+FeedItemProtocol.swift
//  Paperboy
//
//  Created by Riccardo Persello on 23/12/22.
//

import Foundation
import FeedKit

extension AtomFeedEntry: FeedItemProtocol {
    public var description: String? {
        return self.summary?.value
    }
    
    public var publicationDate: Date? {
        return self.updated
    }
    
    public var url: URL? {
        if let link = self.links?.first?.attributes?.href {
            return URL(string: link)
        }
        
        return nil
    }
}
