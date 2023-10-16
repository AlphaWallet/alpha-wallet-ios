// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import BigInt

extension TokenInstanceAction.ActionType: Equatable {
    public static func == (lhs: TokenInstanceAction.ActionType, rhs: TokenInstanceAction.ActionType) -> Bool {
        //Printing lhs and rhs here might crash. Why? (don't remove this comment as we might accidentally trigger it)
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
        case tokenScript(contract: AlphaWallet.Address, title: String, viewHtml: (html: String, urlFragment: String?, style: String), attributes: [AttributeId: AssetAttribute], transactionFunction: FunctionOrigin?, selection: TokenScriptSelection?)
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
    public func viewHtml(tokenId: TokenId) -> (html: String, urlFragment: String?) {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge, .nonFungibleTransfer, .nftRedeem, .nftSell:
            return (html: "", urlFragment: nil)
        case .tokenScript(_, _, (html: let html, let urlFragment, style: let style), _, _, _):
            return (html: wrapWithHtmlViewport(html: html, style: style, forTokenId: tokenId), urlFragment: urlFragment)
        }
    }
}

public protocol TokenActionProvider {
    var action: String { get }
}
