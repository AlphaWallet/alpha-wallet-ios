// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletWeb3
//TODO make only XMLHandler import Kanna and hence be the only file to handle XML parsing
import Kanna

///Handles:
///
///1) origin (function call, token-id, user-entry)
///2) then an optional mapping
///3) then enforce syntax
public struct AssetAttribute {
    private let attribute: XMLElement
    private let xmlContext: XmlContext
    private let origin: Origin
    private let mapping: AssetAttributeMapping?

    public let syntax: AssetAttributeSyntax

    public var userEntryId: AttributeId? {
        return origin.userEntryId
    }
    public var isUserEntryOriginBased: Bool {
        switch origin {
        case .userEntry:
            return true
        case .tokenId, .function, .event:
            return false
        }
    }
    public var isTokenIdOriginBased: Bool {
        switch origin {
        case .tokenId:
            return true
        case .userEntry, .function, .event:
            return false
        }
    }
    public var isFunctionOriginBased: Bool {
        switch origin {
        case .function:
            return true
        case .tokenId, .userEntry, .event:
            return false
        }
    }
    public var isEventOriginBased: Bool {
        switch origin {
        case .event:
            return true
        case .tokenId, .userEntry, .function:
            return false
        }
    }
    public var isDependentOnProps: Bool {
        switch origin {
        case .function(let functionOrigin):
            return functionOrigin.inputs.contains(where: {
                switch $0 {
                case .prop:
                    return true
                case .value, .ref, .cardRef:
                    return false
                }
            })
        case .tokenId, .userEntry, .event:
            return false
        }
    }
    public var name: String {
        return XMLHandler.getNameElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext)?.text ?? ""
    }
    public var eventOrigin: EventOrigin? {
        switch origin {
        case .event(let eventOrigin):
            return eventOrigin
        case .tokenId, .userEntry, .function:
            return nil
        }
    }

    public init?(attribute: XMLElement, xmlContext: XmlContext, root: XMLDocument, tokenContract: AlphaWallet.Address, server: RPCServerOrAny, contractNamesAndAddresses: [String: [(AlphaWallet.Address, RPCServer)]]) {
        guard let syntaxElement = XMLHandler.getSyntaxElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
              let rawValue = syntaxElement.text,
              let syntax = AssetAttributeSyntax(rawValue: rawValue) else { return nil }

        var originFound: Origin?
        if let tokenIdElement = XMLHandler.getTokenIdElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
           XMLHandler.getBitMask(fromTokenIdElement: tokenIdElement) != nil {
            originFound = Origin(forTokenIdElement: tokenIdElement, xmlContext: xmlContext)
        } else if let ethereumFunctionElement: XMLElement = XMLHandler.getEthereumOriginElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
                  ethereumFunctionElement["function"] != nil,
                  let attributeName = attribute["name"],
                  let contract = AssetAttribute.getContract(fromEthereumFunctionElement: ethereumFunctionElement, forTokenContract: tokenContract, server: server, contractNamesAndAddresses: contractNamesAndAddresses) {
            originFound = Origin(forEthereumFunctionElement: ethereumFunctionElement, root: root, originContract: contract, xmlContext: xmlContext)
        } else if let userEntryElement = XMLHandler.getOriginUserEntryElement(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
                  let attributeName = attribute["name"] {
            originFound = Origin(forUserEntryElement: userEntryElement, attributeName: attributeName, xmlContext: xmlContext)
        } else if let ethereumEventElement = XMLHandler.getEthereumOriginElementEvents(fromAttributeTypeElement: attribute, xmlContext: xmlContext),
                  let eventName = ethereumEventElement["type"],
                  let eventContractName = ethereumEventElement["contract"],
                  let eventSourceContractElement = XMLHandler.getContractElementByName(contractName: eventContractName, fromRoot: root, xmlContext: xmlContext),
                  let contract = XMLHandler.getAddressElements(fromContractElement: eventSourceContractElement, xmlContext: xmlContext).first?.text.flatMap({ AlphaWallet.Address(string: $0.trimmed) }),
                  let asnModuleNamedTypeElement = XMLHandler.getAsnModuleNamedTypeElement(fromRoot: root, xmlContext: xmlContext, forTypeName: eventName),
                  attribute["name"] != nil {
            let possibleOrigin = Origin(forEthereumEventElement: ethereumEventElement, asnModuleNamedTypeElement: asnModuleNamedTypeElement, contract: contract, xmlContext: xmlContext)
            switch possibleOrigin {
            case .some(.event(let eventOrigin)):
                //We only want event origins when there's a `select` attribute for attributes, unlike when we use event origins for activity
                if eventOrigin.hasEventParameterName {
                    originFound = possibleOrigin
                } else {
                    originFound = nil
                }
            case .some(.function), .some(.userEntry), .some(.tokenId), .none:
                originFound = possibleOrigin
            }
        }

        guard let origin = originFound else { return nil }
        self.attribute = attribute
        self.xmlContext = xmlContext
        self.syntax = syntax
        self.origin = origin
        self.mapping = origin.extractMapping()
    }

    private static func getContract(fromEthereumFunctionElement ethereumFunctionElement: XMLElement, forTokenContract contract: AlphaWallet.Address, server: RPCServerOrAny, contractNamesAndAddresses: [String: [(AlphaWallet.Address, RPCServer)]]) -> AlphaWallet.Address? {
        if let functionOriginContractName = ethereumFunctionElement["contract"].nilIfEmpty {
            return XMLHandler.functional.getNonTokenHoldingContract(byName: functionOriginContractName, server: server, fromContractNamesAndAddresses: contractNamesAndAddresses)
        } else {
            //TODO falling back to the token contract should only be for activity cards
            return contract
        }
    }

    func value(from tokenIdOrEvent: TokenIdOrEvent, inWallet account: AlphaWallet.Address, server: RPCServer, assetAttributeProvider: CallForAssetAttributeProvider, userEntryValues: [AttributeId: String], tokenLevelNonSubscribableAttributesAndValues: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue]) -> AssetAttributeSyntaxValue {
        let valueFromOriginOptional: AssetInternalValue?
        valueFromOriginOptional = origin.extractValue(fromTokenIdOrEvent: tokenIdOrEvent, inWallet: account, server: server, assetAttributeProvider: assetAttributeProvider, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: tokenLevelNonSubscribableAttributesAndValues, localRefs: localRefs)
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

public class AssetAttributeResolver {
    private let blockchainsProvider: BlockchainsProvider
    private lazy var assetAttributeProvider = CallForAssetAttributeProvider(blockchainsProvider: blockchainsProvider)

    public init(blockchainsProvider: BlockchainsProvider) {
        self.blockchainsProvider = blockchainsProvider
    }

    //This is useful for implementing 3-phase resolution of attributes: resolve the immediate ones (non-function origins), then use those values to resolve the function-origins
    private func splitAttributesByOrigin(for attributes: [AttributeId: AssetAttribute]) -> (tokenIdBased: [AttributeId: AssetAttribute], userEntryBased: [AttributeId: AssetAttribute], functionBased: [AttributeId: AssetAttribute], eventBased: [AttributeId: AssetAttribute]) {
        return (
            tokenIdBased: attributes.filter { $0.value.isTokenIdOriginBased },
            userEntryBased: attributes.filter { $0.value.isUserEntryOriginBased },
            functionBased: attributes.filter { $0.value.isFunctionOriginBased },
            eventBased: attributes.filter { $0.value.isEventOriginBased }
        )
    }

    //Order of resolution is important: token-id, event, user-entry, functions. For now, we don't support functions that have args based on attributes that are also function-based
    public func resolve(withTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, userEntryValues: [AttributeId: String], server: RPCServer, account: AlphaWallet.Address, additionalValues: [AttributeId: AssetAttributeSyntaxValue], localRefs: [AttributeId: AssetInternalValue], attributes: [AttributeId: AssetAttribute]) -> [AttributeId: AssetAttributeSyntaxValue] {
        var attributeNameValues = [AttributeId: AssetAttributeSyntaxValue]()
        let (tokenIdBased, userEntryBased, functionBased, eventBased) = splitAttributesByOrigin(for: attributes)

        for (attributeId, attribute) in tokenIdBased {
            let value = attribute.value(from: tokenIdOrEvent, inWallet: account, server: server, assetAttributeProvider: assetAttributeProvider, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: .init(), localRefs: localRefs)
            attributeNameValues[attributeId] = value
        }
        for (attributeId, attribute) in eventBased {
            let resolvedAttributes = attributeNameValues.merging(additionalValues) { (_, new) in new }
            switch tokenIdOrEvent {
            case .tokenId:
                break
            case .event:
                let value = attribute.value(from: tokenIdOrEvent, inWallet: account, server: server, assetAttributeProvider: assetAttributeProvider, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: resolvedAttributes.mapValues { $0.value }, localRefs: localRefs)
                attributeNameValues[attributeId] = value
            }
        }
        for (attributeId, attribute) in userEntryBased {
            let resolvedAttributes = attributeNameValues.merging(additionalValues) { (_, new) in new }
            let value = attribute.value(from: tokenIdOrEvent, inWallet: account, server: server, assetAttributeProvider: assetAttributeProvider, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: resolvedAttributes.mapValues { $0.value }, localRefs: localRefs)
            attributeNameValues[attributeId] = value
        }
        for (attributeId, attribute) in functionBased {
            let resolvedAttributes = attributeNameValues.merging(additionalValues) { (_, new) in new }
            let value = attribute.value(from: tokenIdOrEvent, inWallet: account, server: server, assetAttributeProvider: assetAttributeProvider, userEntryValues: userEntryValues, tokenLevelNonSubscribableAttributesAndValues: resolvedAttributes.mapValues { $0.value }, localRefs: localRefs)
            attributeNameValues[attributeId] = value
        }
        return attributeNameValues
    }
}
