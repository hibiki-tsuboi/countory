//
//  Item.swift
//  Countory
//
//  Created by Hibiki Tsuboi on 2025/12/15.
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
