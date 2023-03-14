//
//  TokenCardRedemptionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 3/6/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import AlphaWalletFoundation

struct TokenCardRedemptionViewModel {
    let token: Token
    let tokenHolder: TokenHolder
    let session: WalletSession
    let keystore: Keystore

    var headerTitle: String {
        return R.string.localizable.aWalletTokenRedeemShowQRCodeTitle()
    }

    func redeemQrCode() async -> UIImage? {
        let redeem = CreateRedeem(token: token)
        let redeemData: (message: String, qrCode: String)
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc1155:
            return nil
        case .erc875:
            redeemData = redeem.redeemMessage(indices: tokenHolder.indices)
        case .erc721, .erc721ForTickets:
            redeemData = redeem.redeemMessage(tokenIds: tokenHolder.tokens.map { $0.id })
        }
        func _generateQr(account: AlphaWallet.Address) async -> UIImage? {
            do {
                let prompt = R.string.localizable.keystoreAccessKeySign()
                guard let decimalSignature = try await SignatureHelper.signatureAsDecimal(for: redeemData.message, account: account, keystore: keystore, prompt: prompt) else { return nil }
                let qrCodeInfo = redeemData.qrCode + decimalSignature
                return qrCodeInfo.toQRCode()
            } catch {
                return nil
            }
        }

        switch session.account.type {
        case .real(let account), .hardware(let account):
            return await _generateQr(account: account)
        case .watch(let account):
            //TODO should pass in a Config instance instead
            if session.config.development.shouldPretendIsRealWallet {
                return await _generateQr(account: account)
            } else {
                return nil
            }
        }
    }
}
