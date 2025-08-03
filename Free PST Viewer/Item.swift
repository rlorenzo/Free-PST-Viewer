//
//  Item.swift
//  Free PST Viewer
//
//  Created by Rex Lorenzo on 8/3/25.
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
