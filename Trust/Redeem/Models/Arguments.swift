//
//  Arguments.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/11/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

struct Arguments: Codable {
    var from: String
    var to: String
    var indices: [UInt16]
    
    enum CodingKeys: String, CodingKey {
        case from = "_from"
        case to = "_to"
        case indices = "_indices"
    }
}
