//
//  SignatureHelper.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/8/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt

public class SignatureHelper {
    class func signatureAsHex(for message: String, account: AlphaWallet.Address, keystore: Keystore, prompt: String) throws -> String? {
        let signature = keystore.signMessageData(message.data(using: String.Encoding.utf8), for: account, prompt: prompt)
        let signatureHex = try? signature.dematerialize().hex(options: .upperCase)
        guard let data = signatureHex else {
            return nil
        }
        return data
    }

    public class func signatureAsDecimal(for message: String, account: AlphaWallet.Address, keystore: Keystore, prompt: String) throws -> String? {
        guard let signatureHex = try signatureAsHex(for: message, account: account, keystore: keystore, prompt: prompt) else { return nil }
        guard let signatureDecimalString = BigInt(signatureHex, radix: 16)?.description else { return nil }
        return signatureDecimalString
    }
}

extension Result {
    /// Returns the value from `success` Results or `throw`s the error.
    public func dematerialize() throws -> Success {
        switch self {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
    
    public var error: Failure? {
        switch self {
        case let .success:
            return nil
        case let .failure(error):
            return error
        }
    }
}
