//
//  ExportJsonKeystoreFileViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 10/12/21.
//

import Foundation
import PromiseKit
import AlphaWalletFoundation

class ExportJsonKeystoreFileViewModel {
    private let keystore: Keystore
    private let wallet: Wallet

    init(keystore: Keystore, wallet: Wallet) {
        self.keystore = keystore
        self.wallet = wallet
    }

    func computeJsonKeystore(password: String) -> Promise<String> {
        return Promise { seal in
            if wallet.origin == .hd {
                let prompt = R.string.localizable.keystoreAccessKeyNonHdBackup()
                keystore.exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount: wallet.address, prompt: prompt, newPassword: password) { result in
                    switch result {
                    case .success(let jsonString):
                        seal.fulfill(jsonString)
                    case .failure(let error):
                        seal.reject(error)
                    }
                }
            } else {
                let prompt = R.string.localizable.keystoreAccessKeyNonHdBackup()
                keystore.exportRawPrivateKeyForNonHdWalletForBackup(forAccount: wallet.address, prompt: prompt, newPassword: password) { result in
                    switch result {
                    case .success(let jsonString):
                        seal.fulfill(jsonString)
                    case .failure(let error):
                        seal.reject(error)
                    }
                }
            }
        }
    }
}
