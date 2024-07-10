// Copyright © 2018 Stormbird PTE. LTD.

import AlphaWalletAddress
import AlphaWalletCore
import BigInt
import Foundation

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
        case swap(service: TokenActionProvider)
        case bridge(service: TokenActionProvider)
        case buy(service: TokenActionProvider)
        case openTokenScriptViewer
    }

    public var attributes: [AttributeId: AssetAttribute] {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return .init()
        case .nftRedeem, .nftSell, .nonFungibleTransfer, .openTokenScriptViewer:
            return .init()
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
        case .nftRedeem, .nftSell, .nonFungibleTransfer, .openTokenScriptViewer:
            return nil
        }
    }
    public var contract: AlphaWallet.Address? {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer, .openTokenScriptViewer:
            return nil
        }
    }
    public var hasTransactionFunction: Bool {
        return transactionFunction != nil
    }

    public var debugName: String {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge, .nftRedeem, .nftSell, .nonFungibleTransfer, .openTokenScriptViewer:
            return String(describing: self)
        }
    }

    public let type: ActionType

    public init(type: ActionType) {
        self.type = type
    }
    //TODO we can live-reload the action view screen now if we observe for changes
    public func viewHtml(tokenId: TokenId) -> (html: String, urlFragment: String?) {
        switch type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge, .nonFungibleTransfer, .nftRedeem, .nftSell, .openTokenScriptViewer:
            return (html: "", urlFragment: nil)
        }
    }
}

public protocol TokenActionProvider {
    var action: String { get }
}
