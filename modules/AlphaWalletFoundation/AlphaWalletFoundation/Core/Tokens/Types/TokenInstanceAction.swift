// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt

extension TokenInstanceAction.ActionType: Equatable {
    public static func == (lhs: TokenInstanceAction.ActionType, rhs: TokenInstanceAction.ActionType) -> Bool {
        switch (lhs, rhs) {
        case (.erc20Send, .erc20Send):
            return true
        case (.erc20Receive, .erc20Receive):
            return true
        case (.nftRedeem, .nftRedeem):
            return true
        case (.nftSell, .nftSell):
            return true
        case (.nonFungibleTransfer, .nonFungibleTransfer):
            return true
        case (.tokenScript(_, let title1, _, _, _, _), .tokenScript(_, let title2, _, _, _, _)):
            return title1 == title2
        case (.swap(let s1), .swap(let s2)):
            return s1.action == s2.action
        case (.bridge(let s1), .bridge(let s2)):
            return s1.action == s2.action
        case (.buy(let s1), .buy(let s2)):
            return s1.action == s2.action
        default:
            return false
        }
    }
}

public struct TokenInstanceAction {
    public enum ActionType {
        case erc20Send
        case erc20Receive
        case nftRedeem
        case nftSell
        case nonFungibleTransfer
        case tokenScript(contract: AlphaWallet.Address, title: String, viewHtml: (html: String, style: String), attributes: [AttributeId: AssetAttribute], transactionFunction: FunctionOrigin?, selection: TokenScriptSelection?)
        case swap(service: TokenActionProvider)
        case bridge(service: TokenActionProvider)
        case buy(service: TokenActionProvider)
    }

    public var attributes: [AttributeId: AssetAttribute] {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return .init()
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return .init()
        case .tokenScript(_, _, _, let attributes, _, _):
            return attributes
        }
    }
    public var attributesDependencies: [AttributeId: AssetAttribute] {
        guard let transactionFunction = transactionFunction else { return .init() }
        let inputs: [AssetFunctionCall.Argument]
        if let inputValue = transactionFunction.inputValue {
            inputs = transactionFunction.inputs + [inputValue]
        } else {
            inputs = transactionFunction.inputs
        }
        let attributeDependencies = inputs.compactMap { each -> String? in
            switch each {
            case .value, .prop:
                return nil
            case .ref(ref: let ref, _):
                return ref
            case .cardRef(ref: let ref, _):
                return ref
            }
        }
        return attributes.filter { attributeDependencies.contains($0.key) }
    }
    public var transactionFunction: FunctionOrigin? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return nil
        case .tokenScript(_, _, _, _, let transactionFunction, _):
            return transactionFunction
        }
    }
    public var contract: AlphaWallet.Address? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return nil
        case .tokenScript(let contract, _, _, _, _, _):
            return contract
        }
    }
    public var hasTransactionFunction: Bool {
        return transactionFunction != nil
    }
    public let type: ActionType
    
    public init(type: ActionType) {
        self.type = type
    }
    //TODO we can live-reload the action view screen now if we observe for changes
    public func viewHtml(forTokenHolder tokenHolder: TokenHolder, tokenId: TokenId) -> (html: String, hash: Int) {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return (html: "", hash: 0)
        case .nftRedeem:
            return (html: "", hash: 0)
        case .nftSell:
            return (html: "", hash: 0)
        case .nonFungibleTransfer:
            return (html: "", hash: 0)
        case .tokenScript(_, _, (html: let html, style: let style), _, _, _):
            //Just an easy way to generate a hash for style + HTML
            let hash = "\(style)\(html)".hashForCachingHeight
            return (html: wrapWithHtmlViewport(html: html, style: style, forTokenHolder: tokenHolder), hash: hash)
        }
    }

    public func activeExcludingSelection(selectedTokenHolders: [TokenHolder], forWalletAddress walletAddress: AlphaWallet.Address, fungibleBalance: BigInt? = nil) -> TokenScriptSelection? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return nil
        case .tokenScript(_, _, _, _, _, let selection):
            guard let selection = selection else { return nil }
            //TODO handle multiple TokenHolder. We only do single-selections now
            let tokenHolder = selectedTokenHolders[0]
            let parser = TokenScriptFilterParser(expression: selection.filter)
            let filterExpressionIsTrue = parser.parse(withValues: tokenHolder.values, ownerAddress: walletAddress, symbol: tokenHolder.symbol, fungibleBalance: fungibleBalance)
            if filterExpressionIsTrue {
                return selection
            } else {
                return nil
            }
        }
    }

    public func activeExcludingSelection(selectedTokenHolder tokenHolder: TokenHolder, tokenId: TokenId, forWalletAddress walletAddress: AlphaWallet.Address, fungibleBalance: BigInt? = nil) -> TokenScriptSelection? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return nil
        case .tokenScript(_, _, _, _, _, let selection):
            guard let selection = selection,
                  let values = tokenHolder.values(tokenId: tokenId),
                  let symbol = tokenHolder.symbol(tokenId: tokenId) else { return nil }
            let parser = TokenScriptFilterParser(expression: selection.filter)

            let filterExpressionIsTrue = parser.parse(withValues: values, ownerAddress: walletAddress, symbol: symbol, fungibleBalance: fungibleBalance)
            if filterExpressionIsTrue {
                return selection
            } else {
                return nil
            }
        }
    }
}
