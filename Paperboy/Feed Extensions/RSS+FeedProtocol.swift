//
//  RSS+FeedProtocol.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import Foundation
import FeedKit

extension RSSFeed: FeedProtocol {
    public func fetchItems() -> [any FeedItemProtocol] {
        self.items ?? []
    }

    public var iconURL: URL? {
        guard let url = self.image?.url else {
            return nil
        }
        
        return URL(string: url)
    }
}
