//
//  XMLHandler.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//  Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import Kanna
import PromiseKit

enum SingularOrPlural {
    case singular
    case plural
}
enum TitlecaseOrNot {
    case titlecase
    case notTitlecase
}

enum TokenScriptSchema {
    case supportedTokenScriptVersion
    case unsupportedTokenScriptVersion(isOld: Bool)
    case unknownXml
    case others
}

enum TokenScriptSignatureVerificationType: Codable {
    case verified(domainName: String?)
    case verificationFailed
    case notCanonicalizedAndNotSigned

    enum Key: CodingKey {
        case rawValue
        case associatedValue
    }

    enum CodingError: Error {
        case unknownValue
    }

    ///Using this property helps provide some safety so enums are encoded (and decoded) with correct magic number value
    private var encodedValue: Int {
        switch self {
        case .verified:
            return 0
        case .verificationFailed:
            return 1
        case .notCanonicalizedAndNotSigned:
            return 2
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        switch rawValue {
        case TokenScriptSignatureVerificationType.verified(domainName: nil).encodedValue:
            let domainName = try? container.decode(String.self, forKey: .associatedValue)
            self = .verified(domainName: domainName)
        case TokenScriptSignatureVerificationType.verificationFailed.encodedValue:
            self = .verificationFailed
        case TokenScriptSignatureVerificationType.notCanonicalizedAndNotSigned.encodedValue:
            self = .notCanonicalizedAndNotSigned
        default:
            throw CodingError.unknownValue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        switch self {
        case .verified(let domainName):
            try container.encode(encodedValue, forKey: .rawValue)
            try container.encode(domainName, forKey: .associatedValue)
        case .verificationFailed:
            try container.encode(encodedValue, forKey: .rawValue)
        case .notCanonicalizedAndNotSigned:
            try container.encode(encodedValue, forKey: .rawValue)
        }
    }
}

//https://github.com/AlphaWallet/TokenScript/wiki/Visual-representation-of-the-validity-of-TokenScript-files
enum TokenLevelTokenScriptDisplayStatus {
    case type0NoTokenScript
    case type1GoodTokenScriptSignatureGoodOrOptional(isDebugMode: Bool, isSigned: Bool, validatedDomain: String?, message: String)
    case type2BadTokenScript(isDebugMode: Bool, message: String, reason: Reason?)

    enum Reason {
        case oldTokenScriptVersion
        case conflictWithAnotherFile
        case invalidSignature
    }
}

//  Interface to extract data from non fungible token
// swiftlint:disable type_body_length
private class PrivateXMLHandler {
    private static let emptyXMLString = "<tbml:token xmlns:tbml=\"http://attestation.id/ns/tbml\"></tbml:token>"
    private static let emptyXML = try! Kanna.XML(xml: emptyXMLString, encoding: .utf8)
    fileprivate static let tokenScriptNamespace = TokenScript.supportedTokenScriptNamespace

    private var xml: XMLDocument
    private let signatureNamespacePrefix = "ds:"
    private let xhtmlNamespacePrefix = "xhtml:"
    private let xmlContext = PrivateXMLHandler.createXmlContext(withLang: PrivateXMLHandler.lang)
    private let contractAddress: AlphaWallet.Address
    private weak var assetDefinitionStore: AssetDefinitionStore?
    var server: RPCServer?
    //Explicit type so that the variable autocompletes with AppCode
    private lazy var selections = extractSelectionsForToken()
    private let isOfficial: Bool
    private let isCanonicalized: Bool
    lazy private var contractNamesAndAddresses: [String: [(AlphaWallet.Address, RPCServer)]] = extractContractNamesAndAddresses()

    private var tokenElement: XMLElement? {
        return XMLHandler.getTokenElement(fromRoot: xml, xmlContext: xmlContext)
    }

    private var holdingContractElement: XMLElement? {
        return XMLHandler.getHoldingContractElement(fromRoot: xml, xmlContext: xmlContext)
    }

    var hasValidTokenScriptFile: Bool
    let tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus>
    lazy var fields: [AttributeId: AssetAttribute] = extractFieldsForToken()

    var introductionHtmlString: String {
        //TODO fallback to first if not found
        if let introductionElement = XMLHandler.getTbmlIntroductionElement(fromRoot: xml, xmlContext: xmlContext) {
            let html = introductionElement.innerHTML ?? ""
            return sanitize(html: html)
        } else {
            return ""
        }
    }

    var tokenViewIconifiedHtml: (html: String, style: String) {
        guard hasValidTokenScriptFile else { return (html: "", style: "") }
        if let element = XMLHandler.getTokenScriptTokenItemViewHtmlElement(fromRoot: xml, xmlContext: xmlContext) {
            return extractHtml(fromViewElement: element)
        } else {
            return (html: "", style: "")
        }
    }

    var tokenViewHtml: (html: String, style: String) {
        guard hasValidTokenScriptFile else { return (html: "", style: "") }
        if let element = XMLHandler.getTokenScriptTokenViewHtmlElement(fromRoot: xml, xmlContext: xmlContext) {
            return extractHtml(fromViewElement: element)
        } else {
            return (html: "", style: "")
        }
    }

    var actions: [TokenInstanceAction] {
        guard hasValidTokenScriptFile else { return [] }
        var results = [TokenInstanceAction]()
        let fromTokenAsTopLevel = Array(XMLHandler.getTokenScriptTokenInstanceActionCardElements(fromRoot: xml, xmlContext: xmlContext))
        let fromActionAsTopLevel = Array(XMLHandler.getTokenScriptActionOnlyActionElements(fromRoot: xml, xmlContext: xmlContext))
        let actionElements = fromTokenAsTopLevel + fromActionAsTopLevel
        for actionElement in actionElements {
            if let name = XMLHandler.getNameElement(fromActionElement: actionElement, xmlContext: xmlContext)?.text?.trimmed.nilIfEmpty,
               let actionName = actionElement["name"]?.trimmed.nilIfEmpty,
               let viewElement = XMLHandler.getViewElement(fromCardElement: actionElement, xmlContext: xmlContext) {
                let (html: html, style: style) = extractHtml(fromViewElement: viewElement)
                guard !html.isEmpty else { continue }
                let attributes = extractFields(forActionElement: actionElement)
                let functionOrigin = XMLHandler.getActionTransactionFunctionElement(fromActionElement: actionElement, xmlContext: xmlContext).flatMap { self.createFunctionOriginFrom(ethereumFunctionElement: $0) }
                let selection = XMLHandler.getExcludeSelectionId(fromActionElement: actionElement, xmlContext: xmlContext).flatMap { id in
                    self.selections.first { $0.id == id }
                }
                results.append(.init(type: .tokenScript(contract: contractAddress, actionName: actionName, title: name, viewHtml: (html: html, style: style), attributes: attributes, transactionFunction: functionOrigin, selection: selection)))
            }
        }
        if fromActionAsTopLevel.isEmpty {
            holdingContractElement?["interface"]
                    .flatMap { TokenInterfaceType(rawValue: $0) }
                    .flatMap { results.append(contentsOf: defaultActions(forTokenType: $0)) }
        } else {
            //TODO "erc20Send" name is not good for cryptocurrency
            let defaultActionsForCryptoCurrency: [TokenInstanceAction] = [.init(type: .erc20Send), .init(type: .erc20Receive)]
            results.append(contentsOf: defaultActionsForCryptoCurrency)
        }

        return results
    }

    var attributesWithEventSource: [AssetAttribute] {
        fields.values.filter { $0.isEventOriginBased }
    }

    var activityCards: [TokenScriptCard] {
        let cards = Array(XMLHandler.getTokenScriptTokenInstanceActivityCardElements(fromRoot: xml, xmlContext: xmlContext))
        let results: [TokenScriptCard] = cards.compactMap { eachCard in
            guard let name = eachCard["name"],
              let ethereumEventElement = XMLHandler.getEthereumOriginElementEvents(fromAttributeTypeElement: eachCard, xmlContext: xmlContext),
               let eventName = ethereumEventElement["type"],
               let asnModuleNamedElement = XMLHandler.getAsnModuleNamedTypeElement(fromRoot: xml, xmlContext: xmlContext, forTypeName: eventName) else { return nil }
            let optionalContract: AlphaWallet.Address?
            if let eventContractName = ethereumEventElement["contract"],
               let eventSourceContractElement = XMLHandler.getContractElementByName(contractName: eventContractName, fromRoot: xml, xmlContext: xmlContext) {
                let addressElements = XMLHandler.getAddressElements(fromContractElement: eventSourceContractElement, xmlContext: xmlContext)
                optionalContract = addressElements.first?.text.flatMap({ AlphaWallet.Address(string: $0.trimmed) })
            } else {
                optionalContract = contractAddress
            }
            guard let contract = optionalContract, let origin = Origin(forEthereumEventElement: ethereumEventElement, asnModuleNamedTypeElement: asnModuleNamedElement, contract: contract, xmlContext: xmlContext) else { return nil }
            switch origin {
            case .event(let eventOrigin):
                let viewHtml: String
                let viewStyle: String
                let itemViewHtml: String
                let itemViewStyle: String

                if let viewElement = XMLHandler.getViewElement(fromCardElement: eachCard, xmlContext: xmlContext) {
                    (html: viewHtml, style: viewStyle) = extractHtml(fromViewElement: viewElement)
                } else {
                    viewHtml = ""
                    viewStyle = ""
                }
                if let itemViewElement = XMLHandler.getItemViewElement(fromCardElement: eachCard, xmlContext: xmlContext) {
                    (html: itemViewHtml, style: itemViewStyle) = extractHtml(fromViewElement: itemViewElement)
                } else {
                    itemViewHtml = ""
                    itemViewStyle = ""
                }
                return .init(name: name, eventOrigin: eventOrigin, view: (html: viewHtml, style: viewStyle), itemView: (html: itemViewHtml, style: itemViewStyle))
            case .tokenId, .userEntry, .function:
                return nil
            }
        }
        return results
    }

    lazy var fieldIdsAndNames: [AttributeId: String] = {
        return Dictionary(uniqueKeysWithValues: fields.map { idAndAttribute in
            return (idAndAttribute.0, idAndAttribute.1.name)
        })
    }()

    var labelInSingularForm: String? {
        if contractAddress.sameContract(as: Constants.katContractAddress) {
            return R.string.localizable.katTitlecase()
        }

        if let labelStringElement = XMLHandler.getLabelStringElement(fromElement: tokenElement, xmlContext: xmlContext), let label = labelStringElement.text {
            return label
        } else {
            return nil
        }
    }

    var labelInPluralForm: String? {
        if contractAddress.sameContract(as: Constants.katContractAddress) {
            return R.string.localizable.katTitlecase()
        }

        if  let nameElement = XMLHandler.getLabelElementForPluralForm(fromElement: tokenElement, xmlContext: xmlContext), let name = nameElement.text {
            return name
        } else {
            return labelInSingularForm
        }
    }

    static private var lang: String {
        let lang = Locale.preferredLanguages[0]
        if lang.hasPrefix("en") {
            return "en"
        } else if lang.hasPrefix("zh") {
            return "zh"
        } else if lang.hasPrefix("es") {
            return "es"
        } else if lang.hasPrefix("ru") {
            return "ru"
        }
        return "en"
    }

    //TODO maybe this should be removed. We should not use AssetDefinitionStore here because it's easy to create cyclical references and infinite loops since they refer to each other
    convenience init(contract: AlphaWallet.Address, assetDefinitionStore: AssetDefinitionStore) {
        let xmlString = assetDefinitionStore[contract]
        let isOfficial = assetDefinitionStore.isOfficial(contract: contract)
        let isCanonicalized = assetDefinitionStore.isCanonicalized(contract: contract)
        self.init(contract: contract, xmlString: xmlString, isOfficial: isOfficial, isCanonicalized: isCanonicalized, assetDefinitionStore: assetDefinitionStore)
    }

    private init(contract: AlphaWallet.Address, xmlString: String?, isOfficial: Bool, isCanonicalized: Bool, assetDefinitionStore: AssetDefinitionStore) {
        let xmlString = xmlString ?? ""
        self.contractAddress = contract
        self.isOfficial = isOfficial
        self.isCanonicalized = isCanonicalized
        self.assetDefinitionStore = assetDefinitionStore
        //We still compute the TokenScript status even if xmlString is empty because it might be considered empty because there's a conflict
        let tokenScriptStatusPromise = PrivateXMLHandler.computeTokenScriptStatus(forContract: contract, xmlString: xmlString, isOfficial: isOfficial, isCanonicalized: isCanonicalized, assetDefinitionStore: assetDefinitionStore)
        tokenScriptStatus = tokenScriptStatusPromise
        if let tokenScriptStatus = tokenScriptStatusPromise.value {
            let (xml, hasValidTokenScriptFile) = PrivateXMLHandler.storeXmlAccordingToTokenScriptStatus(xmlString: xmlString, tokenScriptStatus: tokenScriptStatus)
            self.xml = xml
            self.hasValidTokenScriptFile = hasValidTokenScriptFile
            //TODO fix for activities. Support base (inheritance)
            if assetDefinitionStore.isBase(contract: contract) {
                if let (_, server, _) = Constants.erc20ContractsSupportingActivities.first(where: { $0.address.sameContract(as: contract) }) {
                    self.server = server
                }
            } else {
                if let (_, server, _) = Constants.erc20ContractsSupportingActivities.first(where: { $0.address.sameContract(as: contract) }) {
                    self.server = server
                } else {
                    self.server = PrivateXMLHandler.extractServer(fromXML: xml, xmlContext: xmlContext, matchingContract: contract)
                }
            }
        } else {
            xml = (try? Kanna.XML(xml: xmlString, encoding: .utf8)) ?? PrivateXMLHandler.emptyXML
            hasValidTokenScriptFile = true
            //TODO fix for activities. Support base (inheritance)
            if assetDefinitionStore.isBase(contract: contract) {
                if let (_, server, _) = Constants.erc20ContractsSupportingActivities.first(where: { $0.address.sameContract(as: contract) }) {
                    self.server = server
                }
            } else {
                if let (_, server, _) = Constants.erc20ContractsSupportingActivities.first(where: { $0.address.sameContract(as: contract) }) {
                    self.server = server
                } else {
                    server = PrivateXMLHandler.extractServer(fromXML: xml, xmlContext: xmlContext, matchingContract: contract)
                }
            }
            tokenScriptStatusPromise.done { tokenScriptStatus in
                let (xml, hasValidTokenScriptFile) = PrivateXMLHandler.storeXmlAccordingToTokenScriptStatus(xmlString: xmlString, tokenScriptStatus: tokenScriptStatus)
                self.xml = xml
                self.hasValidTokenScriptFile = hasValidTokenScriptFile
                //TODO fix for activities. Support base (inheritance)
                if assetDefinitionStore.isBase(contract: contract) {
                    if let (_, server, _) = Constants.erc20ContractsSupportingActivities.first(where: { $0.address.sameContract(as: contract) }) {
                        self.server = server
                    }
                } else {
                    if let (_, server, _) = Constants.erc20ContractsSupportingActivities.first(where: { $0.address.sameContract(as: contract) }) {
                        self.server = server
                    } else {
                        self.server = PrivateXMLHandler.extractServer(fromXML: xml, xmlContext: self.xmlContext, matchingContract: contract)
                    }
                }
                self.assetDefinitionStore?.invalidateSignatureStatus(forContract: self.contractAddress)
            }.cauterize()
        }
    }

    private func extractHtml(fromViewElement element: XMLElement) -> (html: String, style: String) {
        let (style: style, script: script, body: body) = XMLHandler.getTokenScriptTokenViewContents(fromViewElement: element, xmlContext: xmlContext, xhtmlNamespacePrefix: xhtmlNamespacePrefix)
        let sanitizedHtml = sanitize(html: body)
        if sanitizedHtml.isEmpty && script.isEmpty {
            return (html: "", style: "")
        } else {
            return (html: """
                          <script type="text/javascript">
                          \(script)
                          </script>
                          \(sanitizedHtml)
                          """,
                    style: """
                           \(AssetDefinitionStore.standardTokenScriptStyles)
                           <style type="text/css">
                           \(style)
                           </style>
                           """)
        }
    }

    private static func storeXmlAccordingToTokenScriptStatus(xmlString: String, tokenScriptStatus: TokenLevelTokenScriptDisplayStatus) -> (xml: XMLDocument, hasValidTokenScriptFile: Bool) {
        let xml: XMLDocument
        let hasValidTokenScriptFile: Bool
        switch tokenScriptStatus {
        case .type1GoodTokenScriptSignatureGoodOrOptional:
            xml = (try? Kanna.XML(xml: xmlString, encoding: .utf8)) ?? PrivateXMLHandler.emptyXML
            hasValidTokenScriptFile = true
        case .type0NoTokenScript:
            xml = PrivateXMLHandler.emptyXML
            hasValidTokenScriptFile = false
        case .type2BadTokenScript(isDebugMode: let isDebugMode, _, reason: let reason):
            if let reason = reason, isDebugMode {
                switch reason {
                case .invalidSignature:
                    xml = (try? Kanna.XML(xml: xmlString, encoding: .utf8)) ?? PrivateXMLHandler.emptyXML
                    hasValidTokenScriptFile = true
                case .conflictWithAnotherFile, .oldTokenScriptVersion:
                    xml = PrivateXMLHandler.emptyXML
                    hasValidTokenScriptFile = false
                }
            } else {
                xml = PrivateXMLHandler.emptyXML
                hasValidTokenScriptFile = false
            }
        }
        return (xml: xml, hasValidTokenScriptFile: hasValidTokenScriptFile)
    }

    func getToken(
            name: String,
            symbol: String,
            fromTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent,
            index: UInt16,
            inWallet account: Wallet,
            server: RPCServer,
            callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator,
            tokenType: TokenType
    ) -> Token {
        guard tokenIdOrEvent.tokenId != 0 else { return .empty }
        let values: [AttributeId: AssetAttributeSyntaxValue]
        if fields.isEmpty {
            values = .init()
        } else {
            //TODO read from cache again, perhaps based on a timeout/TTL for each attribute. There was a bug with reading from cache sometimes. e.g. cache a token with 8 token origin attributes and 1 function origin attribute and when displaying it and reading from the cache, sometimes it'll only return the 1 function origin attribute in the cache
            values = resolveAttributesBypassingCache(withTokenIdOrEvent: tokenIdOrEvent, server: server, account: account)
            cache(attributeValues: values, forTokenId: tokenIdOrEvent.tokenId)
        }
        return Token(
                tokenIdOrEvent: tokenIdOrEvent,
                tokenType: tokenType,
                index: index,
                name: name,
                symbol: symbol,
                status: .available,
                values: values
        )
    }


    func resolveAttributesBypassingCache(withTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, server: RPCServer, account: Wallet) -> [AttributeId: AssetAttributeSyntaxValue] {
        fields.resolve(withTokenIdOrEvent: tokenIdOrEvent, userEntryValues: .init(), server: server, account: account, additionalValues: .init(), localRefs: .init())
    }

    private static func computeTokenScriptStatus(forContract contract: AlphaWallet.Address, xmlString: String, isOfficial: Bool, isCanonicalized: Bool, assetDefinitionStore: AssetDefinitionStore) -> Promise<TokenLevelTokenScriptDisplayStatus> {
        if assetDefinitionStore.hasConflict(forContract: contract) {
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, message: R.string.localizable.tokenScriptType2ConflictingFiles(), reason: .conflictWithAnotherFile))
        }
        if assetDefinitionStore.hasOutdatedTokenScript(forContract: contract) {
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, message: R.string.localizable.tokenScriptType2OldSchemaVersion(), reason: .oldTokenScriptVersion))
        }
        if xmlString.nilIfEmpty == nil {
            return .value(.type0NoTokenScript)
        }
        let result = XMLHandler.checkTokenScriptSchema(xmlString)
        switch result {
        case .supportedTokenScriptVersion:
            return firstly { () -> Promise<TokenScriptSignatureVerificationType> in
                if let cachedVerificationType = assetDefinitionStore.getCacheTokenScriptSignatureVerificationType(forXmlString: xmlString) {
                    return .value(cachedVerificationType)
                } else {
                    return verificationType(forXml: xmlString, isCanonicalized: isCanonicalized, contractAddress: contract)
                }
            }.then { verificationStatus -> Promise<TokenLevelTokenScriptDisplayStatus> in
                return Promise { seal in
                    assetDefinitionStore.writeCacheTokenScriptSignatureVerificationType(verificationStatus, forContract: contract, forXmlString: xmlString)
                    switch verificationStatus {
                    case .verified(let domainName):
                    seal.fulfill(.type1GoodTokenScriptSignatureGoodOrOptional(isDebugMode: !isOfficial, isSigned: true, validatedDomain: domainName, message: R.string.localizable.tokenScriptType1SupportedAndSigned()))
                    case .verificationFailed:
                        seal.fulfill(.type2BadTokenScript(isDebugMode: !isOfficial, message: R.string.localizable.tokenScriptType2InvalidSignature(), reason: .invalidSignature))
                    case .notCanonicalizedAndNotSigned:
                        //But should always be debug mode because we can't have a non-canonicalized XML from the official repo
                        seal.fulfill(.type1GoodTokenScriptSignatureGoodOrOptional(isDebugMode: !isOfficial, isSigned: false, validatedDomain: nil, message: R.string.localizable.tokenScriptType1SupportedNotCanonicalizedAndUnsigned()))
                    }
                }
            }
        case .unsupportedTokenScriptVersion(let isOld):
            if isOld {
                return .value(.type2BadTokenScript(isDebugMode: !isOfficial, message: "type 2 or bad? Mismatch version. Old version", reason: .oldTokenScriptVersion))
            } else {
                assertImpossibleCodePath()
                return .value(.type2BadTokenScript(isDebugMode: !isOfficial, message: "type 2 or bad? Mismatch version. Unknown schema", reason: nil))
            }
        case .unknownXml:
            assertImpossibleCodePath()
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, message: "unknown. Maybe empty invalid? Doesn't even include something that might be our schema", reason: nil))
        case .others:
            assertImpossibleCodePath()
            return .value(.type2BadTokenScript(isDebugMode: !isOfficial, message: "Not XML?", reason: nil))
        }
    }

    private func getValuesFromCache(forTokenId tokenId: TokenId) -> [AttributeId: AssetAttributeSyntaxValue]? {
        guard let cache = assetDefinitionStore?.assetAttributesCache else { return nil }
        guard let cachedAttributes: [AttributeId: AssetInternalValue] = cache.getValues(forContract: contractAddress, tokenId: tokenId) else { return nil }
        var results: [AttributeId: AssetAttributeSyntaxValue] = .init()
        for (attributeId, attribute) in fields {
            if let value = cachedAttributes[attributeId] {
                results[attributeId] = .init(syntax: attribute.syntax, value: value)
            }
        }
        return results
    }

    private func cache(attributeValues values: [AttributeId: AssetAttributeSyntaxValue], forTokenId tokenId: TokenId) {
        guard !values.isEmpty else { return }
        guard let assetDefinitionStore = assetDefinitionStore else { return }
        let cache = assetDefinitionStore.assetAttributesCache
        let valuesAsDictionary = values.mapValues { $0.value }
        cache.cache(attributes: fields, values: valuesAsDictionary, forContract: contractAddress, tokenId: tokenId)
    }

    private static func extractServer(fromXML xml: XMLDocument, xmlContext: XmlContext, matchingContract contractAddress: AlphaWallet.Address) -> RPCServer? {
        for (contract, chainId) in getHoldingContracts(xml: xml, xmlContext: xmlContext) where contract == contractAddress {
            return .init(chainID: chainId)
        }
        //Might be possible?
        return nil
    }

    private static func verificationType(forXml xmlString: String, isCanonicalized: Bool, contractAddress: AlphaWallet.Address) -> Promise<TokenScriptSignatureVerificationType> {
        let verifier = TokenScriptSignatureVerifier()
        return verifier.verify(xml: xmlString)
    }

    private func defaultActions(forTokenType tokenType: TokenInterfaceType) -> [TokenInstanceAction] {
        let actions: [TokenInstanceAction.ActionType]
        switch tokenType {
        case .erc20:
            actions = [.erc20Send, .erc20Receive]
        case .erc721:
            if contractAddress.isUEFATicketContract {
                actions = [.nftRedeem, .nonFungibleTransfer]
            } else {
                actions = [.nonFungibleTransfer]
            }
        case .erc875:
            if contractAddress.isFifaTicketcontract {
                actions = [.nftRedeem, .nftSell, .nonFungibleTransfer]
            } else {
                actions = [.nftSell, .nonFungibleTransfer]
            }
        }
        return actions.map { .init(type: $0) }
    }

    private func createFunctionOriginFrom(ethereumFunctionElement: XMLElement) -> FunctionOrigin? {
        if let contract = ethereumFunctionElement["contract"].nilIfEmpty {
            guard let server = server else { return nil }
            return XMLHandler.getNonTokenHoldingContract(byName: contract, server: server, fromContractNamesAndAddresses: self.contractNamesAndAddresses)
                    .flatMap { FunctionOrigin(forEthereumFunctionTransactionElement: ethereumFunctionElement, root: xml, attributeId: "", originContract: $0, xmlContext: xmlContext, bitmask: nil, bitShift: 0) }
        } else {
            return XMLHandler.getRecipientAddress(fromEthereumFunctionElement: ethereumFunctionElement, xmlContext: xmlContext)
                    .flatMap { FunctionOrigin(forEthereumPaymentElement: ethereumFunctionElement, root: xml, attributeId: "", recipientAddress: $0, xmlContext: xmlContext, bitmask: nil, bitShift: 0) }
        }
    }

    private func extractContractNamesAndAddresses() -> [String: [(AlphaWallet.Address, RPCServer)]] {
        var result = [String: [(AlphaWallet.Address, RPCServer)]]()
        for eachContractElement in XMLHandler.getContractElements(fromRoot: xml, xmlContext: xmlContext) {
            guard let name = eachContractElement["name"] else { continue }
            let addressElements = XMLHandler.getAddressElements(fromContractElement: eachContractElement, xmlContext: xmlContext)
            result[name] = addressElements.compactMap {
                guard let address = $0.text.flatMap({ AlphaWallet.Address(string: $0.trimmed) }), let chainId = $0["network"].flatMap({ Int($0) }) else { return nil }
                return (address: address, server: RPCServer(chainID: chainId))
            }
        }
        return result
    }

    private func extractFieldsForToken() -> [AttributeId: AssetAttribute] {
        if let tokensElement = XMLHandler.getTokenElement(fromRoot: xml, xmlContext: xmlContext) {
            return extractFields(fromElementContainingAttributes: tokensElement)
        } else {
            return .init()
        }
    }

    private func extractSelectionsForToken() -> [TokenScriptSelection] {
        XMLHandler.getSelectionElements(fromRoot: xml, xmlContext: xmlContext).compactMap { each in
            guard let id = each["name"], let filter = each["filter"]  else { return nil }
            let names = (
                    singular: XMLHandler.getLabelStringElement(fromElement: each, xmlContext: xmlContext)?.text ?? "",
                    plural: XMLHandler.getLabelElementForPluralForm(fromElement: each, xmlContext: xmlContext)?.text
            )
            let denial: String? = XMLHandler.getDenialString(fromElement: each, xmlContext: xmlContext)?.text
            return TokenScriptSelection(id: id, filter: filter, names: names, denial: denial)
        }
    }

    private func extractFields(forActionElement actionElement: XMLElement) -> [AttributeId: AssetAttribute] {
        extractFields(fromElementContainingAttributes: actionElement)
    }

    private func extractFields(fromElementContainingAttributes element: XMLElement) -> [AttributeId: AssetAttribute] {
        var fields = [AttributeId: AssetAttribute]()
        for each in XMLHandler.getAttributeElements(fromAttributeElement: element, xmlContext: xmlContext) {
            guard let name = each["name"] else { continue }
            //TODO we pass in server because we are assuming the server used for non-token-holding contracts are the same as the token-holding contract for now. Not always true. We'll have to fix it in the future when TokenScript supports it
            guard let attribute = server.flatMap({ AssetAttribute(attribute: each, xmlContext: xmlContext, root: xml, tokenContract: contractAddress, server: $0, contractNamesAndAddresses: contractNamesAndAddresses) }) else { continue }
            fields[name] = attribute
        }
        return fields
    }

    //TODOis it still necessary to santize? Maybe we still need to strip a, button, html?
    //TODO Need to cache? Too slow?
    private func sanitize(html: String) -> String {
        return html
    }

    fileprivate static func getHoldingContracts(xml: XMLDocument, xmlContext: XmlContext) -> [(AlphaWallet.Address, Int)] {
        let fromTokenAsTopLevel: [(AlphaWallet.Address, Int)] = XMLHandler.getAddressElementsForHoldingContracts(fromRoot: xml, xmlContext: xmlContext)
                .map { (contract: $0.text, chainId: $0["network"]) }
                .compactMap { (contract, chainId) in
                    if let contract = contract.flatMap({ AlphaWallet.Address(string: $0) }), let chainId = chainId.flatMap({ Int($0) }) {
                        return (contract: contract, chainId: chainId)
                    } else {
                        return nil
                    }
                }
        let fromActionAsTopLevel: [(AlphaWallet.Address, Int)]
        if let server = XMLHandler.getServerForNativeCurrencyAction(fromRoot: xml, xmlContext: xmlContext) {
            fromActionAsTopLevel = [(Constants.nativeCryptoAddressInDatabase, server.chainID)]
        } else {
            fromActionAsTopLevel = []
        }
        return fromTokenAsTopLevel + fromActionAsTopLevel
    }

    fileprivate static func createXmlContext(withLang lang: String) -> XmlContext {
        let rootNamespacePrefix = "ts:"
        let namespaces = [
            "ts": PrivateXMLHandler.tokenScriptNamespace,
            "ds": "http://www.w3.org/2000/09/xmldsig#",
            "xhtml": "http://www.w3.org/1999/xhtml",
            "asnx": "urn:ietf:params:xml:ns:asnx",
            "ethereum": "urn:ethereum:constantinople",
        ]
        return .init(namespacePrefix: rootNamespacePrefix, namespaces: namespaces, lang: lang)
    }

    fileprivate static func getEntities(inXml xml: String) -> [TokenScriptFileIndices.Entity] {
        var entities = [TokenScriptFileIndices.Entity]()
        let pattern = "<\\!ENTITY\\s+(.*)\\s+SYSTEM\\s+\"(.*)\">"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            regex.enumerateMatches(in: xml, options: [], range: .init(xml.startIndex..<xml.endIndex, in: xml)) { match, _, _ in
                guard let match = match else { return }
                guard match.numberOfRanges == 3 else { return }
                guard let entityRange = Range(match.range(at: 1), in: xml), let fileNameRange = Range(match.range(at: 2), in: xml) else { return }
                let entityName = String(xml[entityRange])
                let fileName = String(xml[fileNameRange])
                entities.append(.init(name: entityName, fileName: fileName))
            }
        }
        return entities
    }
}
// swiftlint:enable type_body_length

/// This class delegates all the functionality to a singleton of the actual XML parser. 1 for each contract. So we just parse the XML file 1 time only for each contract
public class XMLHandler {
    //TODO not the best thing to have, especially because it's an optional
    static var callForAssetAttributeCoordinators: ServerDictionary<CallForAssetAttributeCoordinator>?
    fileprivate static var xmlHandlers: [AlphaWallet.Address: PrivateXMLHandler] = [:]
    private let privateXMLHandler: PrivateXMLHandler

    var hasAssetDefinition: Bool {
        return privateXMLHandler.hasValidTokenScriptFile
    }

    var fields: [AttributeId: AssetAttribute] {
        privateXMLHandler.fields
    }

    var tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        return privateXMLHandler.tokenScriptStatus
    }

    var introductionHtmlString: String {
        return privateXMLHandler.introductionHtmlString
    }

    var tokenViewIconifiedHtml: (html: String, style: String) {
        return privateXMLHandler.tokenViewIconifiedHtml
    }

    var tokenViewHtml: (html: String, style: String) {
        return privateXMLHandler.tokenViewHtml
    }

    var actions: [TokenInstanceAction] {
        return privateXMLHandler.actions
    }

    var server: RPCServer? {
        return privateXMLHandler.server
    }

    var attributesWithEventSource: [AssetAttribute] {
        privateXMLHandler.attributesWithEventSource
    }

    var activityCards: [TokenScriptCard] {
        privateXMLHandler.activityCards
    }

    var fieldIdsAndNames: [AttributeId: String] {
        return privateXMLHandler.fieldIdsAndNames
    }

    init(contract: AlphaWallet.Address, assetDefinitionStore: AssetDefinitionStore) {
        if let handler = XMLHandler.xmlHandlers[contract] {
            privateXMLHandler = handler
        } else {
            privateXMLHandler = PrivateXMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore)
            XMLHandler.xmlHandlers[contract] = privateXMLHandler
        }
    }

    static func getNonTokenHoldingContract(byName name: String, server: RPCServer, fromContractNamesAndAddresses contractNamesAndAddresses: [String: [(AlphaWallet.Address, RPCServer)]]) -> AlphaWallet.Address? {
        guard let addressesAndServers = contractNamesAndAddresses[name] else { return nil }
        guard let (contract, _) = addressesAndServers.first(where: { $0.1 == server }) else { return nil }
        return contract
    }

    //Returns nil if the XML schema is not supported
    static func getHoldingContracts(forTokenScript xmlString: String) -> [(AlphaWallet.Address, Int)]? {
        //Lang doesn't matter
        let xmlContext = PrivateXMLHandler.createXmlContext(withLang: "en")

        switch XMLHandler.checkTokenScriptSchema(xmlString) {
        case .supportedTokenScriptVersion:
            if let xml = try? Kanna.XML(xml: xmlString, encoding: .utf8) {
                return PrivateXMLHandler.getHoldingContracts(xml: xml, xmlContext: xmlContext)
            } else {
                return []
            }
        case .unsupportedTokenScriptVersion, .unknownXml, .others:
            return nil
        }

    }

    static func getEntities(forTokenScript xml: String) -> [TokenScriptFileIndices.Entity] {
        return PrivateXMLHandler.getEntities(inXml: xml)
    }

    static func invalidate(forContract contract: AlphaWallet.Address) {
        xmlHandlers[contract] = nil
    }

    public static func invalidateAllContracts() {
        xmlHandlers.removeAll()
    }

    func getToken(name: String, symbol: String, fromTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, index: UInt16, inWallet account: Wallet, server: RPCServer, tokenType: TokenType) -> Token {
        //TODO get rid of the forced unwrap
        let callForAssetAttributeCoordinator = (XMLHandler.callForAssetAttributeCoordinators?[server])!
        return privateXMLHandler.getToken(name: name, symbol: symbol, fromTokenIdOrEvent: tokenIdOrEvent, index: index, inWallet: account, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator, tokenType: tokenType)
    }

    func getLabel(fallback: String = R.string.localizable.tokenTitlecase()) -> String {
        return privateXMLHandler.labelInSingularForm ?? fallback
    }

    func getNameInPluralForm(fallback: String = R.string.localizable.tokensTitlecase()) -> String {
        return privateXMLHandler.labelInPluralForm ?? fallback
    }

    static func checkTokenScriptSchema(forPath path: URL) -> TokenScriptSchema {
        switch path.pathExtension.lowercased() {
        case AssetDefinitionDiskBackingStore.fileExtension, "xml":
            if let contents = (try? String(contentsOf: path)).nilIfEmpty {
                return checkTokenScriptSchema(contents)
            } else {
                //It's fine to have a file that is empty. A CSS file for example
                return .unknownXml
            }
        default:
            return .others
        }
    }

    static func isTokenScriptSupportedSchemaVersion(_ url: URL) -> Bool {
        switch XMLHandler.checkTokenScriptSchema(forPath: url) {
        case .supportedTokenScriptVersion:
            return true
        case .unsupportedTokenScriptVersion:
            return false
        case .unknownXml:
            return false
        case .others:
            return false
        }
    }

    static func checkTokenScriptSchema(_ contents: String) -> TokenScriptSchema {
        //It's fine to have a file that is empty. A CSS file for example. But we should expect the input to be XML
        if let xml = try? Kanna.XML(xml: contents, encoding: .utf8) {
            let namespaces = xml.namespaces.map { $0.name }
            let relevantNamespaces = namespaces.filter { $0.hasPrefix(TokenScript.tokenScriptNamespacePrefix) }
            if relevantNamespaces.isEmpty {
                return .unknownXml
            } else if relevantNamespaces.count == 1, let namespace = relevantNamespaces.first {
                if namespace == TokenScript.supportedTokenScriptNamespace {
                    return .supportedTokenScriptVersion
                } else {
                    if TokenScript.oldNoLongerSupportedTokenScriptNamespaceVersions.contains(namespace) {
                        return .unsupportedTokenScriptVersion(isOld: true)
                    } else {
                        return .unsupportedTokenScriptVersion(isOld: false)
                    }
                }
            } else {
                //Not expecting more than 1 TokenScript namespace
                return .unknownXml
            }
        } else {
            return .unknownXml
        }
    }

    func resolveAttributesBypassingCache(withTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, server: RPCServer, account: Wallet) -> [AttributeId: AssetAttributeSyntaxValue] {
        privateXMLHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: tokenIdOrEvent, server: server, account: account)
    }
}
