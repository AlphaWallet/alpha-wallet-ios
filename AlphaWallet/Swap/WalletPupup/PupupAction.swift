//
//  PupupAction.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit

enum PupupAction: Int, CaseIterable {
    case swap
    case send
    case receive
    case buy

    var title: String {
        switch self {
        case .swap: return "Swap"
        case .send: return "Send"
        case .receive: return "Receive"
        case .buy: return "Buy"
        }
    }

    var description: String? {
        switch self {
        case .swap: return "Swap any tokens"
        case .send: return "Send tokens to another wallet"
        case .receive: return "Show my wallet address"
        case .buy: return "Purchase crypto using Ramp Network"
        }
    }

    var icon: UIImage? {
        return R.image.swap()
    }
}
