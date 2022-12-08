//
//  RSS+FeedItemProtocol.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import Foundation
import FeedKit

extension RSSFeedItem: FeedItemProtocol {
    public var url: URL? {
        guard let link = self.link else {
            return nil
        }
        
        return URL(string: link)
    }
}
