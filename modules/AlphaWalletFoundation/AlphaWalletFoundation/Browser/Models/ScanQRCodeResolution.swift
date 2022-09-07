//
//  ScanQRCodeResolution.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

public enum ScanQRCodeAction: CaseIterable {
    case sendToAddress
    case addCustomToken
    case watchWallet
    case openInEtherscan
}

public enum ScanQRCodeResolution {
    case value(value: QRCodeValue)
    case walletConnect(AlphaWallet.WalletConnect.ConnectionUrl)
    case other(String)
    case url(URL)
    case privateKey(String)
    case seedPhase([String])
    case json(String)

    public init(rawValue: String) {
        let trimmedValue = rawValue.trimmed

        if let value = QRCodeValueParser.from(string: trimmedValue) {
            self = .value(value: value)
        } else if let url = AlphaWallet.WalletConnect.ConnectionUrl(rawValue) {
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
                    self = .other(trimmedValue)
                } else {
                    self = .seedPhase(components)
                }
            }
        }
    }
}

public enum CheckEIP681Error: Error {
    case configurationInvalid
    case contractInvalid
    case parameterInvalid
    case missingRpcServer
}
