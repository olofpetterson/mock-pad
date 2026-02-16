//
//  Item.swift
//  MockPad
//
//  Created by Olof Petterson on 2026-02-16.
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
