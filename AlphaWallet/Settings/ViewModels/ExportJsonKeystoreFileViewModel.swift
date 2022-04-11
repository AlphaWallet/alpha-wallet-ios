//
//  ExportJsonKeystoreFileViewModel.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 10/12/21.
//

import Foundation
import PromiseKit

class ExportJsonKeystoreFileViewModel {
    private let keystore: Keystore
    private let wallet: Wallet

    init(keystore: Keystore, wallet: Wallet) {
        self.keystore = keystore
        self.wallet = wallet
    }

    func computeJsonKeystore(password: String) -> Promise<String> {
        return Promise { seal in
            if keystore.isHdWallet(wallet: wallet) {
                keystore.exportRawPrivateKeyFromHdWallet0thAddressForBackup(forAccount: wallet.address, newPassword: password) { result in
                    switch result {
                    case .success(let jsonString):
                        seal.fulfill(jsonString)
                    case .failure(let error):
                        seal.reject(error)
                    }
                }
            } else {
                keystore.exportRawPrivateKeyForNonHdWalletForBackup(forAccount: wallet.address, newPassword: password) { result in
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
