//
//  BrowserMessageType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation
import WebKit

public enum Browser { }

extension Browser {
    public static let locationChangedEventName = "locationChanged"
    public enum MessageType {
        case dappAction(DappCommand)
        case setActionProps(TokenScript.SetProperties)

        public static func fromMessage(_ message: WKScriptMessage) -> Browser.MessageType? {
            if let action = TokenScript.SetProperties.fromMessage(message) {
                return .setActionProps(action)
            } else if let command = DappAction.fromMessage(message) {
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
}
