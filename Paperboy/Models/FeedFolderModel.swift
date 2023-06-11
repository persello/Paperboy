//
//  FeedFolderModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 11/06/23.
//
//

import Foundation
import SwiftData
import SFSafeSymbols


@Model final public class FeedFolderModel {
    var name: String
    private var icon: String = "\"folder\""
    
    @Relationship(.cascade, inverse: \FeedModel.folder)
    var feeds: [FeedModel]
    
    init(name: String, feeds: [FeedModel] = [], icon: SFSymbol = .folder) {
        self.icon = icon.rawValue
        self.name = name
        self.feeds = feeds
    }
}

extension FeedFolderModel {
    var symbol: SFSymbol {
        return SFSymbol(rawValue: self.icon)
    }
}
