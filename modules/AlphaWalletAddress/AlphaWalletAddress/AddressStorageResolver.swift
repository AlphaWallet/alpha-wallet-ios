//
//  AddressStorageResolver.swift
//  AlphaWalletAddress
//
//  Created by Vladyslav Shepitko on 02.06.2022.
//

import Foundation

//Computing EIP55 is really slow. Cache needed when we need to create many addresses, like parsing a whole lot of Ethereum event logs
//there is cases when cache accessing from different treads, fro this case we need to use sync access for it
var sharedAddressStorage: AddressStorage? = InMemoryAddressStorage()

/// Global function allows to replace address storage
public func register(addressStorage: AddressStorage) {
    sharedAddressStorage = addressStorage
}
