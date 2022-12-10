//
//  FeedItemModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 08/12/22.
//

import Foundation
import CoreData

extension FeedItemModel {
    convenience init<F: FeedItemProtocol>(from item: F, context: NSManagedObjectContext) {
        self.init(context: context)
        self.title = item.title
        self.link = item.url
    }
}
