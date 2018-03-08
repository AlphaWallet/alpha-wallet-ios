//
//  QuantitySelectionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/4/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit

struct QuantitySelectionViewModel {

    var ticketHolder: TicketHolder

    var title: String {
        return "Quantity"
    }

    var maxValue: Int {
        return ticketHolder.tickets.count
    }

}
