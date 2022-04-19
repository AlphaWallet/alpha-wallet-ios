//
//  CBCError.swift
//  CBC
//
//  Created by Gal Yedidovich on 02/08/2021.
//

import Foundation
import CryptoKit

internal struct CBCError: LocalizedError {
    let message: String
    let status: Int32

    var errorDescription: String? {
        return "CBC Error: \"\(message)\", status: \(status)"
    }
}


public extension Data {
    var bytes: [UInt8] {
        [UInt8](self)
    }
}

public extension SymmetricKey {
    /// A Data instance created safely from the contiguous bytes without making any copies.
    var dataRepresentation: Data {
        return withUnsafeBytes { bytes in
            let cfdata = CFDataCreateWithBytesNoCopy(nil, bytes.baseAddress?.assumingMemoryBound(to: UInt8.self), bytes.count, kCFAllocatorNull)
            return (cfdata as Data?) ?? Data()
        }
    }
}
