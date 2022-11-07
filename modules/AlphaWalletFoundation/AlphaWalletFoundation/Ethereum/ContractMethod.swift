//
//  ContractMethod.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.11.2022.
//

import Foundation
import AlphaWalletWeb3
import BigInt

public protocol ContractMethod {
    func encodedABI() throws -> Data
}
