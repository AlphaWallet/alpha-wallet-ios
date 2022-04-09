//
//  ENSError.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/8/22.

import Foundation

struct ENSError: LocalizedError {
    private let localizedDescription: String
    init(description: String) {
        localizedDescription = description
    }

    public var errorDescription: String? {
        return localizedDescription
    }
}