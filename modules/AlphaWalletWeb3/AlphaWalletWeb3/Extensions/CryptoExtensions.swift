//
//  CryptoExtensions.swift
//  web3swift
//
//  Created by Alexander Vlasov on 04.12.2017.
//  Copyright © 2017 Alexander Vlasov. All rights reserved.
//

import Foundation

func toByteArray<T>(_ value: T) -> [UInt8] {
    var value = value
    return withUnsafeBytes(of: &value) { Array($0) }
}

func fromByteArray<T>(_ value: [UInt8], _: T.Type) -> T {
    return value.withUnsafeBytes {
        $0.baseAddress!.load(as: T.self)
    }
}
