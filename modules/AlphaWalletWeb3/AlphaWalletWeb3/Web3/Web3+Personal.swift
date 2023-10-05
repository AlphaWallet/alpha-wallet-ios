//
//  Web3+Personal.swift
//  web3swift
//
//  Created by Alexander Vlasov on 14.04.2018.
//  Copyright © 2018 Bankex Foundation. All rights reserved.
//

import Foundation
import AlphaWalletCore
import BigInt

extension Web3.Personal {

    public func ecrecover(personalMessage: Data, signature: Data) -> Result<EthereumAddress, Error> {
        guard let recovered = Web3.Utils.personalECRecover(personalMessage, signature: signature) else {
            return .failure(DecodeError.initFailure)
        }
        return .success(recovered)
    }

    public func ecrecover(hash: Data, signature: Data) -> Result<EthereumAddress, Error> {
        guard let recovered = Web3.Utils.hashECRecover(hash: hash, signature: signature) else {
            return .failure(DecodeError.initFailure)
        }
        return .success(recovered)
    }
}
