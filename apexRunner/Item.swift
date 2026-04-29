//
//  Item.swift
//  apexRunner
//
//  Created by Talha Gergin on 2.04.2026.
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
