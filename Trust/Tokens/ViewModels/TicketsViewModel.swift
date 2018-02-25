//
//  TicketsViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct TicketsViewModel {

    var token: TokenObject

    var numberOfSections: Int {
        return 2
    }
    
    func numberOfItems(for section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return token.balance.count
    }

}
