//
//  NFTService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.03.2022.
//

import Foundation
import PromiseKit

protocol NFTProvider: AnyObject {
    func nonFungible(wallet: Wallet, server: RPCServer) -> Promise<OpenSeaNonFungiblesToAddress>
}
