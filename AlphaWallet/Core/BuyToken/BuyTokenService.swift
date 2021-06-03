//
//  BuyTokenService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import UIKit

protocol BuyTokenURLProviderType {
    var action: String { get }
    
    func url(token: TokenActionsServiceKey) -> URL?
}
