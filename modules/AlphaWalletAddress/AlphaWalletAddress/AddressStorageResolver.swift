//
//  AddressStorageResolver.swift
//  AlphaWalletAddress
//
//  Created by Vladyslav Shepitko on 02.06.2022.
//

import Foundation

/// Global function allows to replace address storage
public func register(addressStorage: AddressStorage) {
    AlphaWallet.Address.sharedAddressStorage = addressStorage
}
