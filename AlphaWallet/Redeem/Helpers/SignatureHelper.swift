//
//  SignatureHelper.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/8/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt

class SignatureHelper {
    //TODO better to pass in keystore instead of analyticsCoordinator
    class func signatureAsHex(for message: String, account: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) throws -> String? {
        let keystore = try EtherKeystore(analyticsCoordinator: analyticsCoordinator)
        let signature = keystore.signMessageData(message.data(using: String.Encoding.utf8), for: account)
        let signatureHex = try? signature.dematerialize().hex(options: .upperCase)
        guard let data = signatureHex else {
            return nil
        }
        return data
    }

    class func signatureAsDecimal(for message: String, account: AlphaWallet.Address, analyticsCoordinator: AnalyticsCoordinator) throws -> String? {
        guard let signatureHex = try signatureAsHex(for: message, account: account, analyticsCoordinator: analyticsCoordinator) else { return nil }
        guard let signatureDecimalString = BigInt(signatureHex, radix: 16)?.description else { return nil }
        return signatureDecimalString
    }
}
