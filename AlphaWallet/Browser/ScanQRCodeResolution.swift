// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

public enum ScanQRCodeAction: CaseIterable {
    case sendToAddress
    case addCustomToken
    case watchWallet
    case openInEtherscan
}

public enum QrCodeValue {
    case addressOrEip681(value: AddressOrEip681)
    case walletConnect(AlphaWallet.WalletConnect.ConnectionUrl)
    case string(String)
    case url(URL)
    case privateKey(String)
    case seedPhase([String])
    case json(String)

    public init(string: String) async {
        let trimmedValue = string.trimmed

        if let value = AddressOrEip681Parser.from(string: trimmedValue) {
            self = .addressOrEip681(value: value)
        } else if let url = AlphaWallet.WalletConnect.ConnectionUrl(string) {
            self = .walletConnect(url)
        } else if let url = URL(string: trimmedValue), trimmedValue.isValidURL {
            self = .url(url)
        } else {
            if trimmedValue.isValidJSON {
                self = .json(trimmedValue)
            } else if trimmedValue.isPrivateKey {
                self = .privateKey(trimmedValue)
            } else {
                let components = trimmedValue.components(separatedBy: " ")
                if components.isEmpty || components.count == 1 {
                    self = .string(trimmedValue)
                } else {
                    self = .seedPhase(components)
                }
            }
        }
    }
}
