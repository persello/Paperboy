//
//  FeedItemProtocol.swift
//  Paperboy
//
//  Created by Riccardo Persello on 04/12/22.
//

import Foundation

public protocol FeedItemProtocol {
    var title: String? { get }
    var description: String? { get }
    var publicationDate: Date? { get }
    var url: URL? { get }
    
    // TODO: Content with intelligent detection.
}
