//
//  ContractMethod.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.11.2022.
//

import AlphaWalletWeb3
import BigInt
import Foundation

public protocol ContractMethod {
    func encodedABI() throws -> Data
}
