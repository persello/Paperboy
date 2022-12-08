//
//  FeedModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 08/12/22.
//

import Foundation


struct FeedModel {
    var title: String
    var id: String
    var feed: any FeedProtocol

    init<F: FeedProtocol>(feed: F) {
        self.title = feed.title ?? "Untitled feed."
        self.id = feed.id
        self.feed = feed
    }
}

extension FeedModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension FeedModel: Identifiable {
    static func == (lhs: FeedModel, rhs: FeedModel) -> Bool {
        lhs.id == rhs.id
    }
}
