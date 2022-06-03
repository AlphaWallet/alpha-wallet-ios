//
//  AddressStorage.swift
//  AlphaWalletAddress
//
//  Created by Vladyslav Shepitko on 02.06.2022.
//

import Foundation

public typealias AddressKey = String

public protocol AddressStorage {
    subscript(key: AddressKey) -> AlphaWallet.Address? { get set }
}
