//
//  StringInterpolation+Optional.swift
//  Paperboy
//
//  Created by Riccardo Persello on 28/12/22.
//

import Foundation
import os

extension OSLogInterpolation {
  mutating func appendInterpolation<T>(maybe: T?) {
    if let value = maybe {

        self.appendInterpolation(value)
    } else {
        self.appendLiteral("nil")
    }
  }
}
