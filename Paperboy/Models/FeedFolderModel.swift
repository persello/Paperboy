//
//  FeedFolderModel.swift
//  Paperboy
//
//  Created by Riccardo Persello on 26/12/22.
//

import Foundation
import SFSafeSymbols

extension FeedFolderModel {
    var normalisedName: String {
        return self.name ?? "Untitled folder"
    }
    
    var symbol: SFSymbol {
        return SFSymbol(rawValue: self.icon ?? "folder")
    }
}
