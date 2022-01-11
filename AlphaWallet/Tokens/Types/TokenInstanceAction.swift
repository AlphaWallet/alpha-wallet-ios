// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct TokenInstanceAction {
    enum ActionType {
        case erc20Send
        case erc20Receive
        case nftRedeem
        case nftSell
        case nonFungibleTransfer
        case tokenScript(contract: AlphaWallet.Address, title: String, viewHtml: (html: String, style: String), attributes: [AttributeId: AssetAttribute], transactionFunction: FunctionOrigin?, selection: TokenScriptSelection?)
        case swap(service: SwapTokenURLProviderType)
        case bridge(service: BridgeTokenURLProviderType)
        case buy(service: BuyTokenURLProviderType)
    }
    
    var name: String {
        switch type {
        case .erc20Send:
            return R.string.localizable.send(preferredLanguages: Languages.preferred())
        case .erc20Receive:
            return R.string.localizable.receive(preferredLanguages: Languages.preferred())
        case .nftRedeem:
            return R.string.localizable.aWalletTokenRedeemButtonTitle(preferredLanguages: Languages.preferred())
        case .nftSell:
            return R.string.localizable.aWalletTokenSellButtonTitle(preferredLanguages: Languages.preferred())
        case .nonFungibleTransfer:
            return R.string.localizable.aWalletTokenTransferButtonTitle(preferredLanguages: Languages.preferred())
        case .tokenScript(_, let title, _, _, _, _):
            return title
        case .swap(let service):
            return service.action
        case .buy(let service):
            return service.action
        case .bridge(let service):
            return service.action
        }
    }
    var attributes: [AttributeId: AssetAttribute] {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return .init()
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return .init()
        case .tokenScript(_, _, _, let attributes, _, _):
            return attributes
        }
    }
    var attributesDependencies: [AttributeId: AssetAttribute] {
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
    var transactionFunction: FunctionOrigin? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return nil
        case .tokenScript(_, _, _, _, let transactionFunction, _):
            return transactionFunction
        }
    }
    var contract: AlphaWallet.Address? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return nil
        case .tokenScript(let contract, _, _, _, _, _):
            return contract
        }
    }
    var hasTransactionFunction: Bool {
        return transactionFunction != nil
    }
    let type: ActionType

    //TODO we can live-reload the action view screen now if we observe for changes
    func viewHtml(forTokenHolder tokenHolder: TokenHolder, tokenId: TokenId) -> (html: String, hash: Int) {
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

    func activeExcludingSelection(selectedTokenHolders: [TokenHolder], forWalletAddress walletAddress: AlphaWallet.Address, fungibleBalance: BigInt? = nil) -> TokenScriptSelection? {
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

    func activeExcludingSelection(selectedTokenHolder tokenHolder: TokenHolder, tokenId: TokenId, forWalletAddress walletAddress: AlphaWallet.Address, fungibleBalance: BigInt? = nil) -> TokenScriptSelection? {
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
