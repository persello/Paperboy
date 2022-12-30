//
//  Collection+safe.swift
//  Paperboy
//
//  Created by Riccardo Persello on 31/12/22.
//

import Foundation

extension Collection {
    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
