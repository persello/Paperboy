//
//  FeedProtocol.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import Foundation

public protocol FeedProtocol: Hashable, Identifiable {
    var title: String? { get }
    var description: String? { get }
    var url: URL? { get }
    var id: String { get }
    var iconURL: URL? { get }
    
    func fetchItems() -> [any FeedItemProtocol]
}

public extension FeedProtocol where Self: Identifiable {
    var id: String {
        return self.url?.absoluteString ?? UUID().uuidString
    }
}

public extension FeedProtocol where Self: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
