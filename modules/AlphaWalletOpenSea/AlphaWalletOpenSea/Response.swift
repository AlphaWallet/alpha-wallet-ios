//
//  Response.swift
//  AlphaWalletOpenSea
//
//  Created by Hwee-Boon Yar on Apr/30/22.
//

import Foundation

//NOTE: we want to keep response data  even when request has failure while performing multiple page, that is why we use `hasError` flag to determine wether data can be saved to local storage with replacing or merging with existing data
public struct Response<T> {
    public let hasError: Bool
    public let result: T

    init(hasError: Bool, result: T) {
        self.hasError = hasError
        self.result = result
    }
}