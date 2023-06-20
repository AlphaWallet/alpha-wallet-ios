// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import AlphaWalletAttestation

public enum ScanQRCodeAction: CaseIterable {
    case sendToAddress
    case addCustomToken
    case watchWallet
    case openInEtherscan
}

public enum QrCodeValue {
    case addressOrEip681(value: AddressOrEip681)
    case attestation(Attestation)
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
            if let attestation = try? await Attestation.extract(fromUrlString: url.absoluteString) {
                self = .attestation(attestation)
            } else {
                self = .url(url)
            }
        } else {
            if trimmedValue.isValidJSON {
                self = .json(trimmedValue)
            } else if trimmedValue.isPrivateKey {
                self = .privateKey(trimmedValue)
            } else {
                if let attestation = try? await Attestation.extract(fromEncodedValue: trimmedValue, source: trimmedValue) {
                    self = .attestation(attestation)
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
}
