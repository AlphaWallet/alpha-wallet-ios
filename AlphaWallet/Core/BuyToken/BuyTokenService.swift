//
//  BuyTokenService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import Foundation

protocol BuyTokenURLProviderType: TokenActionProvider {
    func url(token: TokenActionsIdentifiable) -> URL?
}
