//
//  QrCodeValue.swift
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

public enum QrCodeValue {
    case addressOrEip681(value: AddressOrEip681)
    case walletConnect(AlphaWallet.WalletConnect.ConnectionUrl)
    case string(String)
    case url(URL)
    case privateKey(String)
    case seedPhase([String])
    case json(String)

    public init(string: String) {
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

public enum CheckEIP681Error: Error, CustomStringConvertible {
    case configurationInvalid
    case contractInvalid
    case parameterInvalid
    case missingRpcServer
    case serverNotEnabled
    case tokenTypeNotSupported
    case notEIP681
    case embeded(error: Error)

    public var description: String {
        switch self {
        case .configurationInvalid:
            return "configurationInvalid"
        case .contractInvalid:
            return "contractInvalid"
        case .parameterInvalid:
            return "parameterInvalid"
        case .missingRpcServer:
            return "missingRpcServer"
        case .tokenTypeNotSupported:
            return "tokenTypeNotSupported"
        case .notEIP681:
            return "notEIP681"
        case .serverNotEnabled:
            return "serverNotEnabled"
        case .embeded(let error):
            return "embedded: \(error)"
        }
    }
}
