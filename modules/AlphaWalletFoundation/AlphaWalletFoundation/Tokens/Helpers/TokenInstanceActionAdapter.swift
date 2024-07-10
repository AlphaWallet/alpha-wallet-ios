//
//  TokenInstanceActionAdapter.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 01.03.2023.
//

import Foundation

import AlphaWalletLogger
import AlphaWalletTokenScript

import BigInt

public struct TokenInstanceActionAdapter {
    private let session: WalletSession
    private let token: Token
    private let tokenHolder: TokenHolder
    private let tokenActionsProvider: SupportedTokenActionsProvider

    public init(session: WalletSession,
                token: Token,
                tokenHolder: TokenHolder,
                tokenActionsProvider: SupportedTokenActionsProvider) {
        self.tokenActionsProvider = tokenActionsProvider
        self.session = session
        self.token = token
        self.tokenHolder = tokenHolder
    }

    public func availableActions() -> [TokenInstanceAction] {
        let xmlHandler = session.tokenAdaptor.xmlHandler(token: token)

        switch token.type {
        case .erc1155, .erc721, .erc721ForTickets, .erc875:
            let actionsFromTokenScript = xmlHandler.actions
            infoLog("[TokenScript] actions names: \(actionsFromTokenScript.map(\.debugName))")
            let results: [TokenInstanceAction]
            if xmlHandler.hasAssetDefinition {
                results = actionsFromTokenScript
            } else {
                switch token.type {
                case .erc1155, .erc721:
                    results = [.init(type: .nonFungibleTransfer) ]
                case .erc875, .erc721ForTickets:
                    results = [
                        .init(type: .nftSell),
                        .init(type: .nonFungibleTransfer),
                    ]
                case .nativeCryptocurrency, .erc20:
                    results = []
                }
            }

            if Features.current.isAvailable(.isNftTransferEnabled) {
                return results
            } else {
                return results.filter { $0.type != .nonFungibleTransfer }
            }
        case .erc20, .nativeCryptocurrency:
            let actionsFromTokenScript = xmlHandler.actions
            infoLog("[TokenScript] actions names: \(actionsFromTokenScript.map(\.debugName))")
            if actionsFromTokenScript.isEmpty {
                switch token.type {
                case .erc875, .erc721, .erc721ForTickets, .erc1155:
                    return []
                case .erc20, .nativeCryptocurrency:
                    let actions: [TokenInstanceAction] = [
                        .init(type: .erc20Send),
                        .init(type: .erc20Receive),
                    ]

                    return actions + tokenActionsProvider.actions(token: token)
                }
            } else {
                switch token.type {
                case .erc875, .erc721, .erc721ForTickets, .erc1155:
                    return []
                case .erc20:
                    return actionsFromTokenScript + tokenActionsProvider.actions(token: token)
                case .nativeCryptocurrency:
                    //TODO we should support retrieval of XML (and XMLHandler) based on address + server. For now, this is only important for native cryptocurrency. So might be ok to check like this for now
                    if let server = xmlHandler.server, server.matches(server: token.server) {
                        return actionsFromTokenScript + tokenActionsProvider.actions(token: token)
                    } else {
                        //TODO .erc20Send and .erc20Receive names aren't appropriate
                        let actions: [TokenInstanceAction] = [
                            .init(type: .erc20Send),
                            .init(type: .erc20Receive),
                        ]

                        return actions + tokenActionsProvider.actions(token: token)
                    }
                }
            }
        }
    }

    public func state(for action: TokenInstanceAction,
                      fungibleBalance: BigUInt?) -> TokenInstanceActionAdapter.ActionState {
        state(
            for: action,
            selectedTokenHolders: [tokenHolder],
            fungibleBalance: fungibleBalance)
    }

    private func state(for action: TokenInstanceAction,
                       selectedTokenHolders: [TokenHolder],
                       fungibleBalance: BigUInt?) -> TokenInstanceActionAdapter.ActionState {
        func _configButton(action: TokenInstanceAction) -> TokenInstanceActionAdapter.ActionState {
            if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address, fungibleBalance: fungibleBalance) {
                if selection.denial == nil {
                    return .isDisplayed(false)
                }
            }
            return .noOption
        }

        switch session.account.type {
        case .real, .hardware:
            return _configButton(action: action)
        case .watch:
            if session.config.development.shouldPretendIsRealWallet {
                return _configButton(action: action)
            } else {
                return .isEnabled(false)
            }
        }
    }
}

extension TokenInstanceActionAdapter {
    public enum ActionState {
        case isDisplayed(Bool)
        case isEnabled(Bool)
        case noOption
    }
}

extension TokenInstanceAction {
    fileprivate func activeExcludingSelection(selectedTokenHolders: [TokenHolder], forWalletAddress walletAddress: AlphaWallet.Address, fungibleBalance: BigUInt? = nil) -> TokenScriptSelection? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer, .openTokenScriptViewer:
            return nil
        }
    }

    public func activeExcludingSelection(selectedTokenHolder tokenHolder: TokenHolder, tokenId: TokenId, forWalletAddress walletAddress: AlphaWallet.Address, fungibleBalance: BigUInt? = nil) -> TokenScriptSelection? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer, .openTokenScriptViewer:
            return nil
        }
    }
}
