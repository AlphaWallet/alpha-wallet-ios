//
//  GetErc20Allowance.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.11.2022.
//

import Foundation
import BigInt
import Combine
import AlphaWalletWeb3

class GetErc20Allowance {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func hasEnoughAllowance(tokenAddress: AlphaWallet.Address, owner: AlphaWallet.Address, spender: AlphaWallet.Address, amount: BigUInt) -> AnyPublisher<(hasEnough: Bool, shortOf: BigUInt), SessionTaskError> {
        if tokenAddress == Constants.nativeCryptoAddressInDatabase {
            return .just((true, 0))
        }

        return blockchainProvider
            .call(Erc20AllowanceMethodCall(contract: tokenAddress, owner: owner, spender: spender))
            .map { allowance -> (Bool, BigUInt) in
                if allowance >= amount {
                    return (true, 0)
                } else {
                    return (false, amount - allowance)
                }
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
