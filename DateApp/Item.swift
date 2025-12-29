//
//  Item.swift
//  DateApp
//
//  Created by Emre Yılmaz on 29.12.2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
