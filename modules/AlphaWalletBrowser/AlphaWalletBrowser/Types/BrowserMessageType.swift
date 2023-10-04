//
//  BrowserMessageType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation
import WebKit
import AlphaWalletLogger

public enum Browser {
    public static let locationChangedEventName = "locationChanged"
}

public enum MessageType {
    case dappAction(DappCommand)
    case setActionProps(SetProperties)

    public static func fromMessage(_ message: WKScriptMessage) -> MessageType? {
        if let action = SetProperties.fromMessage(message) {
            return .setActionProps(action)
        } else if let command = DappOrWalletCommand.fromMessage(message) {
            switch command {
            case .eth(let command):
                return .dappAction(command)
            case .walletAddEthereumChain:
                return nil
            case .walletSwitchEthereumChain:
                return nil
            }
        }
        return nil
    }
}

extension DappOrWalletCommand {
    public static func fromMessage(_ message: WKScriptMessage) -> DappOrWalletCommand? {
        let decoder = JSONDecoder()
        guard var body = message.body as? [String: AnyObject] else {
            infoLog("[Browser] Invalid body in message: \(message.body)")
            return nil
        }
        if var object = body["object"] as? [String: AnyObject], object["gasLimit"] is [String: AnyObject] {
            //Some dapps might wrongly have a gasLimit dictionary which breaks our decoder. MetaMask seems happy with this, so we support it too
            object["gasLimit"] = nil
            body["object"] = object as AnyObject
        }
        guard let jsonString = body.jsonString else {
            infoLog("[Browser] Invalid jsonString. body: \(body)")
            return nil
        }
        let data = jsonString.data(using: .utf8)!
        //We try the stricter form (DappCommand) first before using the one that is more forgiving
        if let command = try? decoder.decode(DappCommand.self, from: data) {
            return .eth(command)
        } else if let commandWithOptionalObjectValues = try? decoder.decode(DappCommandWithOptionalObjectValues.self, from: data) {
            let command = commandWithOptionalObjectValues.toCommand
            return .eth(command)
        } else if let command = try? decoder.decode(AddCustomChainCommand.self, from: data) {
            return .walletAddEthereumChain(command)
        } else if let command = try? decoder.decode(SwitchChainCommand.self, from: data) {
            return .walletSwitchEthereumChain(command)
        } else {
            infoLog("[Browser] failed to parse dapp command with JSON: \(jsonString)")
            return nil
        }
    }
}