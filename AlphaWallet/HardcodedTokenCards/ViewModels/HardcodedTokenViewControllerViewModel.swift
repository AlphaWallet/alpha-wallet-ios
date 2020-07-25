// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt
import PromiseKit

protocol HardcodedTokenViewControllerViewModel {
    var title: String { get }
    var description: String { get }
    var transferType: TransferType { get }
    var session: WalletSession { get }
    var assetDefinitionStore: AssetDefinitionStore { get }
    var headerValueFormatter: HardcodedTokenCardRowFormatter { get }
    var token: TokenObject? { get }
    var fungibleBalance: BigInt? { get }
    var sections: [(section: String, rows: [(title: String, formatter: HardcodedTokenCardRowFormatter, progressBlock: HardcodedTokenCardRowFloatBlock?)])] { get }
    var actions: [TokenInstanceAction] { get }
    var backgroundColor: UIColor { get }
    var sendButtonTitle: String { get }
    var receiveButtonTitle: String { get }
    var iconImage: Subscribable<TokenImage>? { get }
}

extension HardcodedTokenViewControllerViewModel {
    var token: TokenObject? {
        switch transferType {
        case .nativeCryptocurrency:
            //TODO might as well just make .nativeCryptocurrency hold the TokenObject instance too
            return TokensDataStore.etherToken(forServer: session.server)
        case .ERC20Token(let token, _, _):
            return token
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
            return nil
        }
    }

    var actions: [TokenInstanceAction] {
        guard let token = token else { return [] }
        let xmlHandler = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        if actionsFromTokenScript.isEmpty {
            switch token.type {
            case .erc875:
                return []
            case .erc721:
                return []
            case .erc721ForTickets:
                return []
            case .nativeCryptocurrency:
                //TODO .erc20Send and .erc20Receive names aren't appropriate
                return [
                    .init(type: .erc20Send),
                    .init(type: .erc20Receive)
                ]
            case .erc20:
                return [
                    .init(type: .erc20Send),
                    .init(type: .erc20Receive)
                ]
            }
        } else {
            switch token.type {
            case .erc875, .erc721, .erc20, .erc721ForTickets:
                return actionsFromTokenScript
            case .nativeCryptocurrency:
                //TODO we should support retrieval of XML (and XMLHandler) based on address + server. For now, this is only important for native cryptocurrency. So might be ok to check like this for now
                if let server = xmlHandler.server, server == token.server {
                    return actionsFromTokenScript
                } else {
                    //TODO .erc20Send and .erc20Receive names aren't appropriate
                    return [
                        .init(type: .erc20Send),
                        .init(type: .erc20Receive)
                    ]
                }
            }
        }
    }

    var tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        if let token = token {
            let xmlHandler = XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore)
            return xmlHandler.tokenScriptStatus
        } else {
            assertImpossibleCodePath()
            return .value(.type2BadTokenScript(isDebugMode: false, message: "Unknown", reason: nil))
        }
    }

    var fungibleBalance: BigInt? {
        switch transferType {
        case .nativeCryptocurrency:
            let string: String? = session.balanceViewModel.value?.amountShort
            return string.flatMap { EtherNumberFormatter.full.number(from: $0, decimals: session.server.decimals) }
        case .ERC20Token(let tokenObject, _, _):
            return tokenObject.valueBigInt
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
            return nil
        }
    }

    var backgroundColor: UIColor {
        Colors.appBackground
    }

    var sendButtonTitle: String {
        R.string.localizable.send()
    }

    var receiveButtonTitle: String {
        R.string.localizable.receive()
    }

    var iconImage: Subscribable<TokenImage>? {
        token?.icon
    }
}
