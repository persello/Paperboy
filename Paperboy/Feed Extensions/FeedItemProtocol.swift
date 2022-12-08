//
//  FeedItemProtocol.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import Foundation

public protocol FeedItemProtocol: Hashable, Identifiable {
    var title: String? { get }
    var description: String? { get }
    var url: URL? { get }
    var id: String { get }
}

public extension FeedItemProtocol where Self: Identifiable {
    var id: String {
        return self.url?.absoluteString ?? UUID().uuidString
    }
}

public extension FeedItemProtocol where Self: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
