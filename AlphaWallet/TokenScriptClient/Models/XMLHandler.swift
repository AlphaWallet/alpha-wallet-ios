//  XMLHandler.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//  Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import Kanna
import PromiseKit

// swiftlint:disable file_length
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
    var server: RPCServerOrAny?
    //Explicit type so that the variable autocompletes with AppCode
    private lazy var selections = extractSelectionsForToken()
    private let isOfficial: Bool
    private let isCanonicalized: Bool
    private var isBase: Bool {
        baseTokenType != nil
    }
    private let baseTokenType: TokenType?
    lazy private var contractNamesAndAddresses: [String: [(AlphaWallet.Address, RPCServer)]] = extractContractNamesAndAddresses()

    private lazy var tokenElement: XMLElement? = {
        return XMLHandler.getTokenElement(fromRoot: xml, xmlContext: xmlContext)
    }()

    private lazy var holdingContractElement: XMLElement? = {
        return XMLHandler.getHoldingContractElement(fromRoot: xml, xmlContext: xmlContext)
    }()

    fileprivate lazy var tokenType: TokenInterfaceType? = {
        holdingContractElement?["interface"].flatMap { TokenInterfaceType(rawValue: $0) }
    }()

    var hasValidTokenScriptFile: Bool
    let tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus>
    lazy var fields: [AttributeId: AssetAttribute] = extractFieldsForToken()

    lazy var introductionHtmlString: String = {
        //TODO fallback to first if not found
        if let introductionElement = XMLHandler.getTbmlIntroductionElement(fromRoot: xml, xmlContext: xmlContext) {
            let html = introductionElement.innerHTML ?? ""
            return sanitize(html: html)
        } else {
            return ""
        }
    }()

    lazy var tokenViewIconifiedHtml: (html: String, style: String) = {
        guard hasValidTokenScriptFile else { return (html: "", style: "") }
        if let element = XMLHandler.getTokenScriptTokenItemViewHtmlElement(fromRoot: xml, xmlContext: xmlContext) {
            return extractHtml(fromViewElement: element)
        } else {
            return (html: "", style: "")
        }
    }()

    lazy var tokenViewHtml: (html: String, style: String) = {
        guard hasValidTokenScriptFile else { return (html: "", style: "") }
        if let element = XMLHandler.getTokenScriptTokenViewHtmlElement(fromRoot: xml, xmlContext: xmlContext) {
            return extractHtml(fromViewElement: element)
        } else {
            return (html: "", style: "")
        }
    }()

    lazy var actions: [TokenInstanceAction] = {
        guard hasValidTokenScriptFile else { return [] }
        var results = [TokenInstanceAction]()
        let fromTokenAsTopLevel = Array(XMLHandler.getTokenScriptTokenInstanceActionCardElements(fromRoot: xml, xmlContext: xmlContext))
        let fromActionAsTopLevel = Array(XMLHandler.getTokenScriptActionOnlyActionElements(fromRoot: xml, xmlContext: xmlContext))
        let actionElements = fromTokenAsTopLevel + fromActionAsTopLevel
        for actionElement in actionElements {
            if let name = XMLHandler.getNameElement(fromActionElement: actionElement, xmlContext: xmlContext)?.text?.trimmed.nilIfEmpty,
               let viewElement = XMLHandler.getViewElement(fromCardElement: actionElement, xmlContext: xmlContext) {
                let (html: html, style: style) = extractHtml(fromViewElement: viewElement)
                guard !html.isEmpty else { continue }
                let attributes = extractFields(forActionElement: actionElement)
                let functionOrigin = XMLHandler.getActionTransactionFunctionElement(fromActionElement: actionElement, xmlContext: xmlContext).flatMap { self.createFunctionOriginFrom(ethereumFunctionElement: $0) }
                let selection = XMLHandler.getExcludeSelectionId(fromActionElement: actionElement, xmlContext: xmlContext).flatMap { id in
                    self.selections.first { $0.id == id }
                }
                results.append(.init(type: .tokenScript(contract: contractAddress, title: name, viewHtml: (html: html, style: style), attributes: attributes, transactionFunction: functionOrigin, selection: selection)))
            }
        }
        if fromActionAsTopLevel.isEmpty {
            if let baseTokenType = baseTokenType, Features.default.isAvailable(.isActivityEnabled) {
                results.append(contentsOf: defaultActions(forTokenType: baseTokenType))
            } else {
                tokenType.flatMap { results.append(contentsOf: defaultActions(forTokenType: $0)) }
            }
        } else {
            //TODO "erc20Send" name is not good for cryptocurrency
            let defaultActionsForCryptoCurrency: [TokenInstanceAction] = [.init(type: .erc20Send), .init(type: .erc20Receive)]
            results.append(contentsOf: defaultActionsForCryptoCurrency)
        }

        return results
    }()

    lazy var attributesWithEventSource: [AssetAttribute] = {
        fields.values.filter { $0.isEventOriginBased }
    }()

    lazy var activityCards: [TokenScriptCard] = {
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
                return .init(name: name, eventOrigin: eventOrigin, view: (html: viewHtml, style: viewStyle), itemView: (html: itemViewHtml, style: itemViewStyle), isBase: isBase)
            case .tokenId, .userEntry, .function:
                return nil
            }
        }
        return results
    }()

    lazy var fieldIdsAndNames: [AttributeId: String] = {
        return Dictionary(uniqueKeysWithValues: fields.map { idAndAttribute in
            return (idAndAttribute.0, idAndAttribute.1.name)
        })
    }()

    lazy var labelInSingularForm: String? = {
        if contractAddress.sameContract(as: Constants.katContractAddress) {
            return R.string.localizable.katTitlecase()
        }

        if let labelStringElement = XMLHandler.getLabelStringElement(fromElement: tokenElement, xmlContext: xmlContext), let label = labelStringElement.text {
            return label
        } else {
            return nil
        }
    }()

    lazy var labelInPluralForm: String? = {
        if contractAddress.sameContract(as: Constants.katContractAddress) {
            return R.string.localizable.katTitlecase()
        }

        if  let nameElement = XMLHandler.getLabelElementForPluralForm(fromElement: tokenElement, xmlContext: xmlContext), let name = nameElement.text {
            return name
        } else {
            return labelInSingularForm
        }
    }()

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
        self.init(contract: contract, xmlString: xmlString, baseTokenType: nil, isOfficial: isOfficial, isCanonicalized: isCanonicalized, assetDefinitionStore: assetDefinitionStore)
    }

    convenience init(contract: AlphaWallet.Address, baseXml: String, baseTokenType: TokenType, assetDefinitionStore: AssetDefinitionStore) {
        self.init(contract: contract, xmlString: baseXml, baseTokenType: baseTokenType, isOfficial: true, isCanonicalized: true, assetDefinitionStore: assetDefinitionStore)
    }

    private init(contract: AlphaWallet.Address, xmlString: String?, baseTokenType: TokenType?, isOfficial: Bool, isCanonicalized: Bool, assetDefinitionStore: AssetDefinitionStore) {
        let xmlString = xmlString ?? ""
        self.contractAddress = contract
        self.isOfficial = isOfficial
        self.isCanonicalized = isCanonicalized
        self.baseTokenType = baseTokenType
        self.assetDefinitionStore = assetDefinitionStore
        //We still compute the TokenScript status even if xmlString is empty because it might be considered empty because there's a conflict
        let tokenScriptStatusPromise = PrivateXMLHandler.computeTokenScriptStatus(forContract: contract, xmlString: xmlString, isOfficial: isOfficial, isCanonicalized: isCanonicalized, assetDefinitionStore: assetDefinitionStore)
        tokenScriptStatus = tokenScriptStatusPromise
        if let tokenScriptStatus = tokenScriptStatusPromise.value {
            let (xml, hasValidTokenScriptFile) = PrivateXMLHandler.storeXmlAccordingToTokenScriptStatus(xmlString: xmlString, tokenScriptStatus: tokenScriptStatus)
            self.xml = xml
            self.hasValidTokenScriptFile = hasValidTokenScriptFile
            if isBase {
                self.server = .any
            } else {
                self.server = PrivateXMLHandler.extractServer(fromXML: xml, xmlContext: xmlContext, matchingContract: contract).flatMap { .server($0) }
            }
        } else {
            xml = (try? Kanna.XML(xml: xmlString, encoding: .utf8)) ?? PrivateXMLHandler.emptyXML
            hasValidTokenScriptFile = true
            let isBase = baseTokenType != nil
            if isBase {
                self.server = .any
            } else {
                server = PrivateXMLHandler.extractServer(fromXML: xml, xmlContext: xmlContext, matchingContract: contract).flatMap { .server($0) }
            }
            tokenScriptStatusPromise.done { tokenScriptStatus in
                let (xml, hasValidTokenScriptFile) = PrivateXMLHandler.storeXmlAccordingToTokenScriptStatus(xmlString: xmlString, tokenScriptStatus: tokenScriptStatus)
                self.xml = xml
                self.hasValidTokenScriptFile = hasValidTokenScriptFile
                if isBase {
                    self.server = .any
                } else {
                    self.server = PrivateXMLHandler.extractServer(fromXML: xml, xmlContext: self.xmlContext, matchingContract: contract).flatMap { .server($0) }
                }
                if !isBase {
                    self.assetDefinitionStore?.invalidateSignatureStatus(forContract: self.contractAddress)
                }
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
                if Features.default.isAvailable(.shouldLoadTokenScriptWithFailedSignatures) {
                    xml = (try? Kanna.XML(xml: xmlString, encoding: .utf8)) ?? PrivateXMLHandler.emptyXML
                    hasValidTokenScriptFile = true
                } else {
                    xml = PrivateXMLHandler.emptyXML
                    hasValidTokenScriptFile = false
                }
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
            tokenType: TokenType
    ) -> TokenScript.Token {
        guard tokenIdOrEvent.tokenId != 0 else { return .empty }
        let values: [AttributeId: AssetAttributeSyntaxValue]
        if fields.isEmpty {
            values = .init()
        } else {
            //TODO read from cache again, perhaps based on a timeout/TTL for each attribute. There was a bug with reading from cache sometimes. e.g. cache a token with 8 token origin attributes and 1 function origin attribute and when displaying it and reading from the cache, sometimes it'll only return the 1 function origin attribute in the cache
            values = resolveAttributesBypassingCache(withTokenIdOrEvent: tokenIdOrEvent, server: server, account: account)
        }
        return TokenScript.Token(
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
        let result = XMLHandler.functional.checkTokenScriptSchema(xmlString)
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
            if contractAddress.isFifaTicketContract {
                actions = [.nftRedeem, .nftSell, .nonFungibleTransfer]
            } else {
                actions = [.nftSell, .nonFungibleTransfer]
            }
        case .erc1155:
            actions = [.nonFungibleTransfer]
        }
        return actions.map { .init(type: $0) }
    }

    private func defaultActions(forTokenType tokenType: TokenType) -> [TokenInstanceAction] {
        let actions: [TokenInstanceAction.ActionType]
        switch tokenType {
        case .erc20, .nativeCryptocurrency:
            actions = [.erc20Send, .erc20Receive]
        case .erc721, .erc721ForTickets:
            if contractAddress.isUEFATicketContract {
                actions = [.nftRedeem, .nonFungibleTransfer]
            } else {
                actions = [.nonFungibleTransfer]
            }
        case .erc875:
            if contractAddress.isFifaTicketContract {
                actions = [.nftRedeem, .nftSell, .nonFungibleTransfer]
            } else {
                actions = [.nftSell, .nonFungibleTransfer]
            }
        case .erc1155:
            actions = [.nonFungibleTransfer]
        }
        return actions.map { .init(type: $0) }
    }

    private func createFunctionOriginFrom(ethereumFunctionElement: XMLElement) -> FunctionOrigin? {
        if let contract = ethereumFunctionElement["contract"].nilIfEmpty {
            guard let server = server else { return nil }
            return XMLHandler.functional.getNonTokenHoldingContract(byName: contract, server: server, fromContractNamesAndAddresses: self.contractNamesAndAddresses)
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

    //TODOis it still necessary to sanitize? Maybe we still need to strip a, button, html?
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
    private static let regex = try? NSRegularExpression(pattern: "<\\!ENTITY\\s+(.*)\\s+SYSTEM\\s+\"(.*)\">", options: [])
    fileprivate static func getEntities(inXml xml: String) -> [TokenScriptFileIndices.Entity] {
        var entities = [TokenScriptFileIndices.Entity]()

        if let regex = Self.regex {
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

final class ThreadSafe {
    private let queue: DispatchQueue

    public init(label: String, qos: DispatchQoS = .background) {
        self.queue = DispatchQueue(label: label, qos: qos)
    }

    func performSync(_ callback: () -> Void) {
        if Thread.isMainThread {
            callback()
        } else {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync {
                callback()
            }
        }
    }
}

fileprivate let threadSafeFoXmlHandler = ThreadSafe(label: "org.alphawallet.swift.xmlHandler.xmlHandlers")
/// This class delegates all the functionality to a singleton of the actual XML parser. 1 for each contract. So we just parse the XML file 1 time only for each contract
public class XMLHandler {
    static var callForAssetAttributeCoordinator = CallForAssetAttributeCoordinator()
    fileprivate static var xmlHandlers = AtomicDictionary<AlphaWallet.Address, PrivateXMLHandler>()
    fileprivate static var baseXmlHandlers = AtomicDictionary<String, PrivateXMLHandler>()
    private let privateXMLHandler: PrivateXMLHandler
    private let baseXMLHandler: PrivateXMLHandler?
    private let threadSafe: ThreadSafe = threadSafeFoXmlHandler

    var hasAssetDefinition: Bool {
        var hasAssetDefinition: Bool = true
        threadSafe.performSync {
            if baseXMLHandler == nil {
                hasAssetDefinition = privateXMLHandler.hasValidTokenScriptFile
            } else {
                hasAssetDefinition = true
            }
        }
        return hasAssetDefinition
    }

    var hasNoBaseAssetDefinition: Bool {
        var hasNoBaseAssetDefinition: Bool = false
        threadSafe.performSync {
            hasNoBaseAssetDefinition = privateXMLHandler.hasValidTokenScriptFile
        }
        return hasNoBaseAssetDefinition
    }

    var fields: [AttributeId: AssetAttribute] {
        var fields: [AttributeId: AssetAttribute] = [:]
        threadSafe.performSync {
            //TODO cache?
            if let baseXMLHandler = baseXMLHandler {
                let overrides = privateXMLHandler.fields
                let base = baseXMLHandler.fields
                fields = base.merging(overrides) { _, new in new }
            } else {
                fields = privateXMLHandler.fields
            }
        }
        return fields
    }

    var tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus> {
        var tokenScriptStatus: Promise<TokenLevelTokenScriptDisplayStatus>!
        threadSafe.performSync {
            tokenScriptStatus = privateXMLHandler.tokenScriptStatus
        }
        return tokenScriptStatus
    }

    var introductionHtmlString: String {
        var introductionHtmlString: String = ""
        threadSafe.performSync {
            introductionHtmlString = privateXMLHandler.introductionHtmlString
        }
        return introductionHtmlString
    }

    var tokenViewIconifiedHtml: (html: String, style: String) {
        var tokenViewIconifiedHtml: (html: String, style: String)!
        threadSafe.performSync {
            let (html: html, style: _) = privateXMLHandler.tokenViewIconifiedHtml
            if let baseXMLHandler = baseXMLHandler {
                if html.isEmpty {
                    tokenViewIconifiedHtml = baseXMLHandler.tokenViewIconifiedHtml
                } else {
                    tokenViewIconifiedHtml = privateXMLHandler.tokenViewIconifiedHtml
                }
            } else {
                tokenViewIconifiedHtml = privateXMLHandler.tokenViewIconifiedHtml
            }
        }
        return tokenViewIconifiedHtml
    }

    var tokenViewHtml: (html: String, style: String) {
        var tokenViewHtml: (html: String, style: String)!
        threadSafe.performSync {
            let (html: html, style: _) = privateXMLHandler.tokenViewHtml
            if let baseXMLHandler = baseXMLHandler {
                if html.isEmpty {
                    tokenViewHtml = baseXMLHandler.tokenViewHtml
                } else {
                    tokenViewHtml = privateXMLHandler.tokenViewHtml
                }
            } else {
                tokenViewHtml = privateXMLHandler.tokenViewHtml
            }
        }
        return tokenViewHtml
    }

    var actions: [TokenInstanceAction] {
        var result: [TokenInstanceAction] = []
        threadSafe.performSync {
            if let baseXMLHandler = baseXMLHandler {
                let overrides = privateXMLHandler.actions
                let base = baseXMLHandler.actions
                let overrideNames = overrides.map { $0.name }
                result = overrides + base.filter { !overrideNames.contains($0.name) }
            } else {
                result = privateXMLHandler.actions
            }
        }
        infoLog("[TokenScript] actions names: \(result.map(\.name))")

        return result
    }

    var server: RPCServerOrAny? {
        var server: RPCServerOrAny?
        threadSafe.performSync {
            if let baseXMLHandler = baseXMLHandler {
                server = baseXMLHandler.server
            } else {
                server = privateXMLHandler.server
            }
        }
        return server
    }

    var attributesWithEventSource: [AssetAttribute] {
        var attributesWithEventSource: [AssetAttribute] = []
        threadSafe.performSync {
        //TODO cache?
            if let baseXMLHandler = baseXMLHandler {
                let overrides = privateXMLHandler.attributesWithEventSource
                let base = baseXMLHandler.attributesWithEventSource
                let overrideNames = overrides.map { $0.name }
                attributesWithEventSource = overrides + base.filter { !overrideNames.contains($0.name) }
            } else {
                attributesWithEventSource = privateXMLHandler.attributesWithEventSource
            }
        }
        return attributesWithEventSource
    }

    var activityCards: [TokenScriptCard] {
        var activityCards: [TokenScriptCard] = []
        threadSafe.performSync {
            //TODO cache?
            if let baseXMLHandler = baseXMLHandler {
                let overrides = privateXMLHandler.activityCards
                let base = baseXMLHandler.activityCards
                let overrideNames = overrides.map { $0.name }
                activityCards = overrides + base.filter { !overrideNames.contains($0.name) }
            } else {
                activityCards = privateXMLHandler.activityCards
            }
        }
        return activityCards
    }

    var fieldIdsAndNames: [AttributeId: String] {
        var fieldIdsAndNames: [AttributeId: String] = [:]
        threadSafe.performSync {
            //TODO cache?
            if let baseXMLHandler = baseXMLHandler {
                let overrides = privateXMLHandler.fieldIdsAndNames
                let base = baseXMLHandler.fieldIdsAndNames
                fieldIdsAndNames = base.merging(overrides) { _, new in new }
            } else {
                fieldIdsAndNames = privateXMLHandler.fieldIdsAndNames
            }
        }
        return fieldIdsAndNames
    }

    convenience init(token: TokenScriptSupportable, assetDefinitionStore: AssetDefinitionStore) {
        self.init(contract: token.contractAddress, tokenType: token.type, assetDefinitionStore: assetDefinitionStore)
    }

    convenience init(contract: AlphaWallet.Address, tokenType: TokenType, assetDefinitionStore: AssetDefinitionStore) {
        self.init(contract: contract, optionalTokenType: tokenType, assetDefinitionStore: assetDefinitionStore)
    }

    //private because we don't want client code creating XMLHandler(s) to be able to accidentally pass in a nil TokenType
    private init(contract: AlphaWallet.Address, optionalTokenType tokenType: TokenType?, assetDefinitionStore: AssetDefinitionStore) {
        var privateXMLHandler: PrivateXMLHandler!
        var baseXMLHandler: PrivateXMLHandler!
        threadSafe.performSync {
            if let handler = XMLHandler.xmlHandlers[contract] {
                privateXMLHandler = handler
            } else {
                privateXMLHandler = PrivateXMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore)
                XMLHandler.xmlHandlers[contract] = privateXMLHandler
            }

            if Features.default.isAvailable(.isActivityEnabled), let tokenType = tokenType {
                let tokenTypeForBaseXml: TokenType
                if privateXMLHandler.hasValidTokenScriptFile, let tokenTypeInXml = privateXMLHandler.tokenType.flatMap({ TokenType(tokenInterfaceType: $0) }) {
                    tokenTypeForBaseXml = tokenTypeInXml
                } else {
                    tokenTypeForBaseXml = tokenType
                }

                //Key cannot be just `contract`, because the type can change (from the overriding TokenScript file)
                let key = "\(contract.eip55String)-\(tokenTypeForBaseXml.rawValue)"
                if let handler = XMLHandler.baseXmlHandlers[key] {
                    baseXMLHandler = handler
                } else {
                    if let xml = TokenScript.baseTokenScriptFiles[tokenTypeForBaseXml] {
                        baseXMLHandler = PrivateXMLHandler(contract: contract, baseXml: xml, baseTokenType: tokenTypeForBaseXml, assetDefinitionStore: assetDefinitionStore)
                        XMLHandler.baseXmlHandlers[key] = baseXMLHandler
                    } else {
                        baseXMLHandler = nil
                    }
                }
            } else {
                baseXMLHandler = nil
            }
        }

        self.baseXMLHandler = baseXMLHandler
        self.privateXMLHandler = privateXMLHandler
    }

    func getToken(name: String, symbol: String, fromTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, index: UInt16, inWallet account: Wallet, server: RPCServer, tokenType: TokenType) -> TokenScript.Token {
        //TODO get rid of the forced unwrap
        var token: TokenScript.Token!
        threadSafe.performSync {
            let overrides = privateXMLHandler.getToken(name: name, symbol: symbol, fromTokenIdOrEvent: tokenIdOrEvent, index: index, inWallet: account, server: server, tokenType: tokenType)
            if let baseXMLHandler = baseXMLHandler {
                let base = baseXMLHandler.getToken(name: name, symbol: symbol, fromTokenIdOrEvent: tokenIdOrEvent, index: index, inWallet: account, server: server, tokenType: tokenType)
                let baseValues = base.values
                let overriddenValues = overrides.values
                token = TokenScript.Token(
                        tokenIdOrEvent: overrides.tokenIdOrEvent,
                        tokenType: overrides.tokenType,
                        index: overrides.index,
                        name: overrides.name,
                        symbol: overrides.symbol,
                        status: overrides.status,
                        //TODO cache?
                        values: baseValues.merging(overriddenValues) { _, new in new }
                )
            } else {
                token = overrides
            }
        }

        return token
    }

    func getLabel(fallback: String = R.string.localizable.tokenTitlecase()) -> String {
        var label: String = ""
        threadSafe.performSync {
            if let baseXMLHandler = baseXMLHandler {
                label = privateXMLHandler.labelInSingularForm ?? baseXMLHandler.labelInSingularForm ?? fallback
            } else {
                label = privateXMLHandler.labelInSingularForm ?? fallback
            }
        }
        return label
    }

    func getNameInPluralForm(fallback: String = R.string.localizable.tokensTitlecase()) -> String {
        var nameInPluralForm: String = ""
        threadSafe.performSync {
            if let baseXMLHandler = baseXMLHandler {
                nameInPluralForm = privateXMLHandler.labelInPluralForm ?? baseXMLHandler.labelInPluralForm ?? fallback
            } else {
                nameInPluralForm = privateXMLHandler.labelInPluralForm ?? fallback
            }
        }
        return nameInPluralForm
    }

    func resolveAttributesBypassingCache(withTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, server: RPCServer, account: Wallet) -> [AttributeId: AssetAttributeSyntaxValue] {
        var attributes: [AttributeId: AssetAttributeSyntaxValue] = [:]
        threadSafe.performSync {
            let overrides = privateXMLHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: tokenIdOrEvent, server: server, account: account)
            if let baseXMLHandler = baseXMLHandler {
                //TODO This is inefficient because overridden attributes get resolved too
                let base = baseXMLHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: tokenIdOrEvent, server: server, account: account)
                attributes = base.merging(overrides) { _, new in new }
            } else {
                attributes = overrides
            }
        }

        return attributes
    }

    static func invalidate(forContract contract: AlphaWallet.Address) {
        xmlHandlers[contract] = nil
    }

    public static func invalidateAllContracts() {
        xmlHandlers.removeAll()
    }

}

extension XMLHandler {
    enum functional {}
}

extension XMLHandler.functional {

    static func tokenScriptStatus(forContract contract: AlphaWallet.Address, assetDefinitionStore: AssetDefinitionStore) -> Promise<TokenLevelTokenScriptDisplayStatus> {
        XMLHandler(contract: contract, optionalTokenType: nil, assetDefinitionStore: assetDefinitionStore).tokenScriptStatus
    }

    static func getNonTokenHoldingContract(byName name: String, server: RPCServerOrAny, fromContractNamesAndAddresses contractNamesAndAddresses: [String: [(AlphaWallet.Address, RPCServer)]]) -> AlphaWallet.Address? {
        guard let addressesAndServers = contractNamesAndAddresses[name] else { return nil }
        switch server {
        case .any:
            //TODO returning the first seems arbitrary, but I don't think TokenScript design has explored this area yet
            guard let (contract, _) = addressesAndServers.first else { return nil }
            return contract
        case .server(let server):
            guard let (contract, _) = addressesAndServers.first(where: { $0.1 == server }) else { return nil }
            return contract
        }
    }

    //Returns nil if the XML schema is not supported
    static func getHoldingContracts(forTokenScript xmlString: String) -> [(AlphaWallet.Address, Int)]? {
        //Lang doesn't matter
        let xmlContext = PrivateXMLHandler.createXmlContext(withLang: "en")

        switch XMLHandler.functional.checkTokenScriptSchema(xmlString) {
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
        switch XMLHandler.functional.checkTokenScriptSchema(forPath: url) {
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
}
// swiftlint:enable file_length
