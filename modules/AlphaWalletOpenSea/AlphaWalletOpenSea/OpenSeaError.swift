//
//  OpenSeaError.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation

//TODO rename/improve
public struct OpenSeaError: Error {
    var localizedDescription: String

    public init(localizedDescription: String) {
        self.localizedDescription = localizedDescription
    }
}