// Copyright © 2022 Stormbird PTE. LTD.

import UIKit
import AlphaWalletTokenScript
import PromiseKit

public protocol ConfirmTokenScriptActionTransactionDelegate: AnyObject {
    func confirmTransactionSelected(in navigationController: UINavigationController, token: Token, contract: AlphaWallet.Address, tokenId: TokenId, values: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore, transactionFunction: FunctionOrigin)
}

//Needed because there is `TokenScript.Token` and we don't want to use that
public typealias FoundationToken = Token

//TODO should move into AlphaWalletTokenScript
extension TokenScript {
    public static func performTokenScriptAction(_ action: TokenInstanceAction, token: FoundationToken, tokenId: TokenId, tokenHolder: TokenHolder, userEntryIds: [String], fetchUserEntries: [Promise<Any?>], localRefsSource: TokenScriptLocalRefsSource, assetDefinitionStore: AssetDefinitionStore, keystore: Keystore, server: RPCServer, session: WalletSession, confirmTokenScriptActionTransactionDelegate: ConfirmTokenScriptActionTransactionDelegate?, navigationController: UINavigationController) {
        guard action.hasTransactionFunction else { return }

        let xmlHandler = assetDefinitionStore.xmlHandler(forContract: token.contractAddress, tokenType: token.type)
        let tokenLevelAttributeValues = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: tokenHolder.tokens[0].tokenIdOrEvent, server: server, account: session.account.address)
        let resolveTokenLevelSubscribableAttributes = Array(tokenLevelAttributeValues.values).filterToSubscribables.createPromiseForSubscribeOnce()

        firstly {
            when(fulfilled: resolveTokenLevelSubscribableAttributes)
        }.then {
            when(fulfilled: fetchUserEntries)
        }.map { (userEntryValues: [Any?]) -> [AttributeId: String] in
            guard let values = userEntryValues as? [String] else { return .init() }
            let zippedIdsAndValues = zip(userEntryIds, values).map { (userEntryId, value) -> (AttributeId, String)? in
                //Should always find a matching attribute
                guard action.attributes.values.first(where: { $0.userEntryId == userEntryId }) != nil else { return nil }
                return (userEntryId, value)
            }.compactMap { $0 }
            return Dictionary(uniqueKeysWithValues: zippedIdsAndValues)
        }.then { userEntryValues -> Promise<[AttributeId: AssetInternalValue]> in
            //Make sure to resolve every attribute before actionsheet appears without hitting the cache. Both action and token-level attributes (especially function-origins)
            //TODO also have to monitor for changes to the attributes, be able to flag it and update actionsheet. Maybe just a matter of getting a list of AssetAttributes and their subscribables (AssetInternalValue?), subscribing to them so that we can indicate changes?
            let (_, tokenIdBased) = tokenLevelAttributeValues.splitAttributesIntoSubscribablesAndNonSubscribables
            return resolveActionAttributeValues(action: action, withUserEntryValues: userEntryValues, tokenLevelTokenIdOriginAttributeValues: tokenIdBased, tokenHolder: tokenHolder, server: server, session: session, localRefsSource: localRefsSource, assetDefinitionStore: assetDefinitionStore)
        }.map { (values: [AttributeId: AssetInternalValue]) -> [AttributeId: AssetInternalValue] in
            //Force unwrap because we know they have been resolved earlier in this promise chain
            let allAttributesAndValues = values.merging(tokenLevelAttributeValues.mapValues { $0.value.resolvedValue! }) { (_, new) in new }
            return allAttributesAndValues
        }.done { values in
            guard let transactionFunction = action.transactionFunction else { return }
            let contract = transactionFunction.originContractOrRecipientAddress
            guard transactionFunction.generateDataAndValue(withTokenId: tokenId, attributeAndValues: values, localRefs: localRefsSource.localRefs, server: server, wallet: session.account.address) != nil else { return }
            confirmTokenScriptActionTransactionDelegate?.confirmTransactionSelected(in: navigationController, token: token, contract: contract, tokenId: tokenId, values: values, localRefs: localRefsSource.localRefs, server: server, session: session, keystore: keystore, transactionFunction: transactionFunction)
        }.cauterize()
        //TODO catch
    }

    private static func resolveActionAttributeValues(action: TokenInstanceAction, withUserEntryValues userEntryValues: [AttributeId: String], tokenLevelTokenIdOriginAttributeValues: [AttributeId: AssetAttributeSyntaxValue], tokenHolder: TokenHolder, server: RPCServer, session: WalletSession, localRefsSource: TokenScriptLocalRefsSource, assetDefinitionStore: AssetDefinitionStore) -> Promise<[AttributeId: AssetInternalValue]> {
        //TODO Not reading/writing from/to cache here because we haven't worked out volatility of attributes yet. So we assume all attributes used by an action as volatile, have to fetch the latest
        //Careful to only resolve (and wait on) attributes that the smart contract function invocation is dependent on. Some action-level attributes might only be used for display
        //TODO why does this resolution not go through an XMLHandler?
        let attributeNameValues = assetDefinitionStore.assetAttributeResolver.resolve(withTokenIdOrEvent: tokenHolder.tokens[0].tokenIdOrEvent, userEntryValues: userEntryValues, server: server, account: session.account.address, additionalValues: tokenLevelTokenIdOriginAttributeValues, localRefs: localRefsSource.localRefs, attributes: action.attributesDependencies).mapValues { $0.value }

        let attributes = AssetAttributeValues(attributeValues: attributeNameValues)
        return attributes.resolveAllAttributes().promise()
    }
}

extension TokenScript {
    public enum functional {}
}

extension TokenScript.functional {
    public static func isNoView(html: String, style: String) -> Bool {
        return html.isEmpty && style.isEmpty
    }
}
