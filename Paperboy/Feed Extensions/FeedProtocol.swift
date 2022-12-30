//
//  FeedProtocol.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import Foundation

public protocol FeedProtocol {
    associatedtype ArticleType: FeedItemProtocol
    
    var title: String? { get }
    var description: String? { get }
    var iconURL: URL? { get }
    var websiteURL: URL? { get }
    var articles: [ArticleType] { get }
}
