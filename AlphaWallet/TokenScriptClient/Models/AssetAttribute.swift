// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt
import PromiseKit
//TODO make only XMLHandler import Kanna and hence be the only file to handle XML parsing
import Kanna

///Handles:
///
///1) origin (function call, token-id, user-entry)
///2) then an optional mapping
///3) then enforce syntax
struct AssetAttribute {
    private let attribute: XMLElement
    private let xmlContext: XmlContext
    private let origin: Origin
    private let mapping: AssetAttributeMapping?

    let syntax: AssetAttributeSyntax

    var userEntryId: AttributeId? {
        return origin.userEntryId
    }
    var isUserEntryOriginBased: Bool {
        switch origin {
        case .userEntry:
            return true
        case .tokenId, .function, .event:
            return false
        }
    }
    var isTokenIdOriginBased: Bool {
        switch origin {
        case .tokenId:
            return true
        case .userEntry, .function, .event:
            return false
        }
    }
    var isFunctionOriginBased: Bool {
        switch origin {
        case .function:
            return true
        case .tokenId, .userEntry, .event:
            return false
        }
    }
    var isEventOriginBased: Bool {
        switch origin {
        case .event:
            return true
        case .tokenId, .userEntry, .function:
            return false
        }
    }
    var name: String {
        return XMLHandler.getNameElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext)?.text ?? ""
    }
    var eventOrigin: EventOrigin? {
        switch origin {
        case .event(let eventOrigin):
            return eventOrigin
        case .tokenId, .userEntry, .function:
            return nil
        }
    }

    init?(attribute: XMLElement, xmlContext: XmlContext, root: XMLDocument, server: RPCServer, contractNamesAndAddresses: [String: [(AlphaWallet.Address, RPCServer)]]) {
        guard let rawSyntax = attribute["syntax"],
              let syntax = AssetAttributeSyntax(rawValue: rawSyntax) else { return nil }

        var originFound: Origin? = nil
        if let tokenIdElement = XMLHandler.getTokenIdElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
           XMLHandler.getBitMask(fromTokenIdElement: tokenIdElement) != nil {
            originFound = Origin(forTokenIdElement: tokenIdElement, xmlContext: xmlContext)
        } else if let ethereumFunctionElement = XMLHandler.getEthereumOriginElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
                  ethereumFunctionElement["function"] != nil,
                  let attributeId = attribute["id"],
                  let functionOriginContractName = ethereumFunctionElement["contract"].nilIfEmpty,
                  let contract = XMLHandler.getNonTokenHoldingContract(byName: functionOriginContractName, server: server, fromContractNamesAndAddresses: contractNamesAndAddresses) {
            originFound = Origin(forEthereumFunctionElement: ethereumFunctionElement, attributeId: attributeId, originContract: contract, xmlContext: xmlContext)
        } else if let userEntryElement = XMLHandler.getOriginUserEntryElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
                  let attributeId = attribute["id"] {
            originFound = Origin(forUserEntryElement: userEntryElement, attributeId: attributeId, xmlContext: xmlContext)
        } else if let ethereumEventElement = XMLHandler.getEthereumOriginElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
                  let eventName = ethereumEventElement["event"],
                  let eventSourceContractElement = root.at_xpath("contract[asnx:module[@name='\(eventName)']]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces),
                  let _ = attribute["id"] {
            originFound = Origin(forEthereumEventElement: ethereumEventElement, sourceContractElement: eventSourceContractElement, xmlContext: xmlContext)
        }

        guard let origin = originFound else { return nil }
        self.attribute = attribute
        self.xmlContext = xmlContext
        self.syntax = syntax
        self.origin = origin
        self.mapping = origin.extractMapping()
    }

    func value(from tokenIdOrEvent: TokenIdOrEvent, inWallet account: Wallet, server: RPCServer, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator, userEntryValues: [AttributeId: String], tokenLevelNonSubscribableAttributesAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue]) -> AssetAttributeSyntaxValue {
        let valueFromOriginOptional: AssetInternalValue?
        valueFromOriginOptional = origin.extractValue(fromTokenIdOrEvent: tokenIdOrEvent, inWallet: account, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: tokenLevelNonSubscribableAttributesAndValues, localRefs: localRefs)
        guard let valueFromOrigin = valueFromOriginOptional else { return .init(defaultValueWithSyntax: syntax) }

        let valueAfterMapping: AssetInternalValue
        if let mapping = mapping {
            guard let output = mapping.map(fromKey: valueFromOrigin) else { return .init(defaultValueWithSyntax: syntax) }
            valueAfterMapping = output
        } else {
            valueAfterMapping = valueFromOrigin
        }
        return .init(syntax: syntax, value: valueAfterMapping)
    }
}

extension Dictionary where Key == AttributeId, Value == AssetAttribute {
    //This is useful for implementing 3-phase resolution of attributes: resolve the immediate ones (non-function origins), then use those values to resolve the function-origins
    var splitAttributesByOrigin: (tokenIdBased: [Key: Value], userEntryBased: [Key: Value], functionBased: [Key: Value], eventBased: [Key: Value]) {
        return (
                tokenIdBased: filter { $0.value.isTokenIdOriginBased },
                userEntryBased: filter { $0.value.isUserEntryOriginBased },
                functionBased: filter { $0.value.isFunctionOriginBased },
                eventBased: filter { $0.value.isEventOriginBased }
        )
    }

    //Order of resolution is important: token-id, event, user-entry, functions. For now, we don't support functions that have args based on attributes that are also function-based
    func resolve(withTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, userEntryValues: [AttributeId: String], server: RPCServer, account: Wallet, additionalValues: [AttributeId: AssetAttributeSyntaxValue], localRefs: [AttributeId: AssetInternalValue]) -> [AttributeId: AssetAttributeSyntaxValue] {
        var attributeNameValues = [AttributeId: AssetAttributeSyntaxValue]()
        let (tokenIdBased, userEntryBased, functionBased, eventBased) = splitAttributesByOrigin
        //TODO get rid of the forced unwrap
        let callForAssetAttributeCoordinator = (XMLHandler.callForAssetAttributeCoordinators?[server])!
        for (attributeId, attribute) in tokenIdBased {
            let value = attribute.value(from: tokenIdOrEvent, inWallet: account, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: .init(), localRefs: localRefs)
            attributeNameValues[attributeId] = value
        }
        for (attributeId, attribute) in eventBased {
            let resolvedAttributes = attributeNameValues.merging(additionalValues) { (_, new) in new }
            switch tokenIdOrEvent {
            case .tokenId:
                break
            case .event:
                let value = attribute.value(from: tokenIdOrEvent, inWallet: account, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: resolvedAttributes.mapValues { $0.value }, localRefs: localRefs)
                attributeNameValues[attributeId] = value
            }
        }
        for (attributeId, attribute) in userEntryBased {
            let resolvedAttributes = attributeNameValues.merging(additionalValues) { (_, new) in new }
            let value = attribute.value(from: tokenIdOrEvent, inWallet: account, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: resolvedAttributes.mapValues { $0.value }, localRefs: localRefs)
            attributeNameValues[attributeId] = value
        }
        for (attributeId, attribute) in functionBased {
            let resolvedAttributes = attributeNameValues.merging(additionalValues) { (_, new) in new }
            let value = attribute.value(from: tokenIdOrEvent, inWallet: account, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: resolvedAttributes.mapValues { $0.value }, localRefs: localRefs)
            attributeNameValues[attributeId] = value
        }
        return attributeNameValues
    }
}
