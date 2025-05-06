//
//  Item.swift
//  HatchEd
//
//  Created by Sandi Junker on 5/6/25.
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
