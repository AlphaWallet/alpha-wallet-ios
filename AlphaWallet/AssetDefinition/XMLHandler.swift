//
//  XMLHandler.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//  Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import Kanna
import TrustKeystore

enum SingularOrPlural {
    case singular
    case plural
}
enum TitlecaseOrNot {
    case titlecase
    case notTitlecase
}

enum SchemaCheckResult {
    case supported
    case unsupported
    case unknown
}

enum TokenScriptFileCheckResult {
    case supportedTokenScriptVersion
    case unsupportedTokenScriptVersion
    case unknownXml
    case others
}

enum TokenScriptVerificationType {
    case verified
    case unverified
    case notCanonicalized
}

//  Interface to extract data from non fungible token
private class PrivateXMLHandler {
    private static let emptyXMLString = "<tbml:token xmlns:tbml=\"http://attestation.id/ns/tbml\"></tbml:token>"
    private static let emptyXML = try! Kanna.XML(xml: emptyXMLString, encoding: .utf8)
    fileprivate static let tokenScriptNamespace = "http://tokenscript.org/2019/04/tokenscript"

    private let xml: XMLDocument
    private let rootNamespacePrefix = "ts:"
    private let signatureNamespacePrefix = "ds:"
    private let xhtmlNamespacePrefix = "xhtml:"
    private let namespaces = [
        "ts": PrivateXMLHandler.tokenScriptNamespace,
        "ds": "http://www.w3.org/2000/09/xmldsig#",
        "xhtml": "http://www.w3.org/1999/xhtml"
    ]
    private let contractAddress: String
    private lazy var fields = extractFields()
    private let isOfficial: Bool
    private let isCanonicalized: Bool

    private var tokenElement: XMLElement? {
        return XMLHandler.getTokenElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, namespaces: namespaces)
    }

    private var contractElement: XMLElement? {
        return XMLHandler.getContractElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, namespaces: namespaces)
    }

    let hasAssetDefinition: Bool

    var introductionHtmlString: String {
        let lang = getLang()
        //TODO fallback to first if not found
        if let introductionElement = XMLHandler.getTbmlIntroductionElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, forLang: lang) {
            let html = introductionElement.innerHTML ?? ""
            return sanitize(html: html)
        } else {
            return ""
        }
    }

    var tokenViewIconifiedHtml: String {
        guard hasAssetDefinition else { return "" }
        let lang = getLang()
        if let element = XMLHandler.getTokenScriptTokenViewIconifiedHtmlElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, forLang: lang) {
            let html = element.innerHTML ?? ""
            let sanitizedHtml = sanitize(html: html)
            if sanitizedHtml.isEmpty {
                return sanitizedHtml
            } else {
                if let styleElement = XMLHandler.getTokenScriptTokenViewIconifiedStyleElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, xhtmlNamespacePrefix: xhtmlNamespacePrefix, namespaces: namespaces), let style = styleElement.text {
                    return """
                           \(AssetDefinitionStore.standardTokenScriptStyles)
                           <style type="text/css">
                           \(style)
                           </style>
                           \(sanitizedHtml)
                           """
                } else {
                    return """
                           \(AssetDefinitionStore.standardTokenScriptStyles)
                           \(sanitizedHtml)
                           """
                }
            }
        } else {
            return ""
        }
    }

    var tokenViewHtml: String {
        guard hasAssetDefinition else { return "" }
        let lang = getLang()
        if let element = XMLHandler.getTokenScriptTokenViewHtmlElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, forLang: lang) {
            let html = element.innerHTML ?? ""
            let sanitizedHtml = sanitize(html: html)
            if sanitizedHtml.isEmpty {
                return sanitizedHtml
            } else {
                if let styleElement = XMLHandler.getTokenScriptTokenViewIconifiedStyleElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, xhtmlNamespacePrefix: xhtmlNamespacePrefix, namespaces: namespaces), let style = styleElement.text {
                    return """
                           \(AssetDefinitionStore.standardTokenScriptStyles)
                           <style type="text/css">
                           \(style)
                           </style>
                           \(sanitizedHtml)
                           """
                } else {
                    return """
                           \(AssetDefinitionStore.standardTokenScriptStyles)
                           \(sanitizedHtml)
                           """
                }
            }
        } else {
            return ""
        }
    }

    var actions: [TokenInstanceAction] {
        guard hasAssetDefinition else { return [] }
        let lang = getLang()
        var results = [TokenInstanceAction]()
        for actionElement in XMLHandler.getTokenScriptTokenInstanceActionElements(fromRoot: xml, namespacePrefix: rootNamespacePrefix, namespaces: namespaces) {
            if let name = XMLHandler.getNameElement(fromActionElement: actionElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, forLang: lang)?.text?.trimmed, !name.isEmpty,
               let viewElement = XMLHandler.getViewElement(fromActionElement: actionElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, forLang: lang) {
                let rawHtml = viewElement.innerHTML ?? ""
                let sanitizedHtml = sanitize(html: rawHtml)
                guard !sanitizedHtml.isEmpty else { continue }
                let html: String
                if let styleElement = XMLHandler.getTokenScriptActionViewStyleElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, xhtmlNamespacePrefix: xhtmlNamespacePrefix, namespaces: namespaces), let style = styleElement.text {
                    html = """
                           \(AssetDefinitionStore.standardTokenScriptStyles)
                           <style type="text/css">
                           \(style)
                           </style>
                           \(sanitizedHtml)
                           """
                } else {
                    html = """
                           \(AssetDefinitionStore.standardTokenScriptStyles)
                           \(sanitizedHtml)
                           """
                }
                results.append(.init(type: .tokenScript(title: name, viewHtml: html)))
            }
        }
        if contractElement?["interface"] == "erc875" {
            results.append(.init(type: .erc875Redeem))
            results.append(.init(type: .erc875Sell))
            results.append(.init(type: .nonFungibleTransfer))
        }

        return results
    }

    lazy var fieldIdsAndNames: [String: String] = {
        return Dictionary(uniqueKeysWithValues: fields.map { (id, attribute) in
            return (id, attribute.name)
        })
    }()

    var nameInSingularForm: String? {
        if contractAddress.sameContract(as: Constants.cryptoKittiesContractAddress) {
            return R.string.localizable.cryptokittyTitlecase()
        }

        let lang = getLang()
        if  let nameElement = XMLHandler.getNameElement(fromTokenElement: tokenElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, lang: lang), let name = nameElement.text {
            return name
        } else {
            return nil
        }
    }

    var nameInPluralForm: String? {
        if contractAddress.sameContract(as: Constants.cryptoKittiesContractAddress) {
            return R.string.localizable.cryptokittiesTitlecase()
        }

        let lang = getLang()
        if  let nameElement = XMLHandler.getNameElementForCollective(fromTokenElement: tokenElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, lang: lang), let name = nameElement.text {
            return name
        } else {
            return nameInSingularForm
        }
    }

    //TODO maybe this should be removed. We should not use AssetDefinitionStore here because it's easy to create cyclical references and infinite loops since they refer to each other
    convenience init(contract: String, assetDefinitionStore: AssetDefinitionStore) {
        let xmlString = assetDefinitionStore[contract]
        let isOfficial = assetDefinitionStore.isOfficial(contract: contract)
        let isCanonicalized = assetDefinitionStore.isCanonicalized(contract: contract)
        self.init(contract: contract, xmlString: xmlString, isOfficial: isOfficial, isCanonicalized: isCanonicalized)
    }

    init(contract: String, xmlString: String?, isOfficial: Bool, isCanonicalized: Bool) {
        self.contractAddress = contract.add0x.lowercased()
        hasAssetDefinition = xmlString != nil
        if let xmlString = xmlString {
            xml = (try? Kanna.XML(xml: xmlString, encoding: .utf8)) ?? PrivateXMLHandler.emptyXML
        } else {
            xml = PrivateXMLHandler.emptyXML
        }
        self.isOfficial = isOfficial
        self.isCanonicalized = isCanonicalized
    }

    func getToken(name: String, symbol: String, fromTokenId tokenBytes32: BigUInt, index: UInt16, server: RPCServer, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator?) -> Token {
        guard tokenBytes32 != 0 else { return .empty }
        var values = [String: AssetAttributeValue]()
        for (name, attribute) in fields {
            let value = attribute.extract(from: tokenBytes32, ofContract: contractAddress, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator)
            values[name] = value
        }

        return Token(
                id: tokenBytes32,
                index: index,
                name: name,
                symbol: symbol,
                status: .available,
                values: values
        )
    }

    func verificationType(for server: RPCServer) -> TokenScriptVerificationType {
        guard let contractElement = contractElement else { return .unverified }
        //TODO We assume that if we get it from the repo server, it's verified if server matches. But we should implementation signature verification.
        if isOfficial {
            for each in XMLHandler.getAddressElements(fromContractElement: contractElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, server: server) {
                if let contractInXml = each.text, contractInXml.sameContract(as: contractAddress) {
                    return .verified
                }
            }
            return .unverified
        } else {
            if isCanonicalized {
                return .unverified
            } else {
                return .notCanonicalized
            }
        }
    }

    private func extractFields() -> [String: AssetAttribute] {
        let lang = getLang()
        var fields = [String: AssetAttribute]()
        for each in XMLHandler.getAttributeTypeElements(fromRoot: xml, namespacePrefix: rootNamespacePrefix, namespaces: namespaces) {
            if let id = each["id"],
               XMLHandler.getBitMaskFrom(fromAttributeTypeElement: each, namespacePrefix: rootNamespacePrefix, namespaces: namespaces) != nil {
                fields[id] = AssetAttribute(attribute: each, rootNamespacePrefix: rootNamespacePrefix, namespaces: namespaces, lang: lang)
            } else if let id = each["id"],
                      let originElement = XMLHandler.getOriginElement(fromAttributeTypeElement: each, namespacePrefix: rootNamespacePrefix, namespaces: namespaces),
                      originElement["contract"] == "holding-contract",
                      let functionElement = XMLHandler.getFunctionElement(fromOriginElement: originElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces) {
                fields[id] = AssetAttribute(attribute: each, functionElement: functionElement, rootNamespacePrefix: rootNamespacePrefix, namespaces: namespaces, lang: lang)
            }
        }
        return fields
    }

    private func getLang() -> String {
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

    func getIssuer() -> String {
        if let keyNameElement = XMLHandler.getKeyNameElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, signatureNamespacePrefix: signatureNamespacePrefix, namespaces: namespaces), let issuer = keyNameElement.text {
            return issuer
        } else {
            return ""
        }
    }

    //TODOis it still necessary to santize? Maybe we still need to strip a, button, html?
    //TODO Need to cache? Too slow?
    private func sanitize(html: String) -> String {
        return html
    }

    func getContracts() -> [(String, Int)] {
        guard let contractElement = contractElement else { return [] }
        return XMLHandler.getAddressElements(fromContractElement: contractElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces)
                .map { (contract: $0.text, chainId: $0["network"]) }
                .compactMap { (contract, chainId) in
                    if let contract = contract, let chainIdStr = chainId, let chainId = Int(chainIdStr) {
                        return (contract: contract.add0x.lowercased(), chainId: chainId)
                    } else {
                        return nil
                    }
                }
    }

    func getEntities() -> [TokenScriptFileIndices.Entity] {
        guard let contents = xml.toXML else { return [] }
        var entities = [TokenScriptFileIndices.Entity]()
        let pattern = "<\\!ENTITY\\s+(.*)\\s+SYSTEM\\s+\"(.*)\">"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            regex.enumerateMatches(in: contents, options: [], range: .init(contents.startIndex..<contents.endIndex, in: contents)) { match, _, _ in
                guard let match = match else { return }
                guard match.numberOfRanges == 3 else { return }
                guard let entityRange = Range(match.range(at: 1), in: contents), let fileNameRange = Range(match.range(at: 2), in: contents) else { return }
                let entityName = String(contents[entityRange])
                let fileName = String(contents[fileNameRange])
                entities.append(.init(name: entityName, fileName: fileName))
            }
        }
        return entities
    }
}

/// This class delegates all the functionality to a singleton of the actual XML parser. 1 for each contract. So we just parse the XML file 1 time only for each contract
public class XMLHandler {
    static var callForAssetAttributeCoordinators: ServerDictionary<CallForAssetAttributeCoordinator>?
    fileprivate static var xmlHandlers: [String: PrivateXMLHandler] = [:]
    private let privateXMLHandler: PrivateXMLHandler

    var hasAssetDefinition: Bool {
        return privateXMLHandler.hasAssetDefinition
    }

    var introductionHtmlString: String {
        return privateXMLHandler.introductionHtmlString
    }

    var tokenViewIconifiedHtml: String {
        return privateXMLHandler.tokenViewIconifiedHtml
    }

    var tokenViewHtml: String {
        return privateXMLHandler.tokenViewHtml
    }

    var actions: [TokenInstanceAction] {
        return privateXMLHandler.actions
    }

    var fieldIdsAndNames: [String: String] {
        return privateXMLHandler.fieldIdsAndNames
    }

    init(contract: String, assetDefinitionStore: AssetDefinitionStore) {
        let contract = contract.add0x.lowercased()
        if let handler = XMLHandler.xmlHandlers[contract] {
            privateXMLHandler = handler
        } else {
            privateXMLHandler = PrivateXMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore)
            XMLHandler.xmlHandlers[contract] = privateXMLHandler
        }
    }

    static func getContracts(forTokenScript xml: String) -> [(String, Int)] {
        //TODO contract and official or not doesn't matter here. Can this be improved?
        let xmlHandler = PrivateXMLHandler(contract: "", xmlString: xml, isOfficial: false, isCanonicalized: true)
        return xmlHandler.getContracts()
    }

    static func getEntities(forTokenScript xml: String) -> [TokenScriptFileIndices.Entity] {
        //TODO contract and official or not doesn't matter here. Can this be improved?
        let xmlHandler = PrivateXMLHandler(contract: "", xmlString: xml, isOfficial: false, isCanonicalized: false)
        return xmlHandler.getEntities()
    }

    public static func invalidate(forContract contract: String) {
        xmlHandlers[contract.add0x.lowercased()] = nil
    }

    public static func invalidateAllContracts() {
        xmlHandlers.removeAll()
    }

    func getToken(name: String, symbol: String,fromTokenId tokenBytes32: BigUInt, index: UInt16, server: RPCServer) -> Token {
        let callForAssetAttributeCoordinator = XMLHandler.callForAssetAttributeCoordinators?[server]
        return privateXMLHandler.getToken(name: name, symbol: symbol, fromTokenId: tokenBytes32, index: index, server: server, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator)
    }

    func getName(fallback: String = R.string.localizable.tokenTitlecase()) -> String {
        return privateXMLHandler.nameInSingularForm ?? fallback
    }

    func getNameInPluralForm(fallback: String = R.string.localizable.tokensTitlecase()) -> String {
        return privateXMLHandler.nameInPluralForm ?? fallback
    }

    func getIssuer() -> String {
        return privateXMLHandler.getIssuer()
    }

    func verificationType(for server: RPCServer) -> TokenScriptVerificationType {
        return privateXMLHandler.verificationType(for: server)
    }

    private static func checkSchema(ofXml xmlString: String) -> SchemaCheckResult {
        if let xml = try? Kanna.XML(xml: xmlString, encoding: .utf8) {
            let namespaces = xml.namespaces.map { $0.name }
            let relevantNamespaces = namespaces.filter { $0.hasPrefix(Constants.tokenScriptNamespacePrefix) }
            if relevantNamespaces.isEmpty {
                return .unknown
            } else if relevantNamespaces.count == 1, let namespace = relevantNamespaces.first {
                if namespace == Constants.supportedTokenScriptNamespace {
                    return .supported
                } else {
                    return .unsupported
                }
            } else {
                //Not expecting more than 1 TokenScript namespace
                return .unknown
            }
        } else {
            return .unknown
        }
    }

    static func isValidAssetDefinitionContent(forPath path: URL) -> TokenScriptFileCheckResult {
        switch path.pathExtension.lowercased() {
        case AssetDefinitionDiskBackingStore.fileExtension, "xml":
            if let contents = try? String(contentsOf: path), !contents.isEmpty {
                switch checkSchema(ofXml: contents) {
                case .supported:
                    return .supportedTokenScriptVersion
                case .unsupported:
                    return .unsupportedTokenScriptVersion
                case .unknown:
                    return .unknownXml
                }
            } else {
                //It's fine to have a file that is empty. A CSS file for example
                return .unknownXml
            }
        default:
            return .others
        }
    }
}

extension String {
	func addToXPath(namespacePrefix: String) -> String {
		let components = split(separator: "/")
		let path = components.map { "\(namespacePrefix)\($0)" }.joined(separator: "/")
		if hasPrefix("/") {
			return "/\(path)"
		} else {
			return path
		}
	}
}

///Access via XPaths
extension XMLHandler {
    fileprivate static func getTokenElement(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        return root.at_xpath("/token".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    fileprivate static func getContractElement(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        return root.at_xpath("/token/contract".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    fileprivate static func getAddressElements(fromContractElement contractElement: Searchable, namespacePrefix: String, namespaces: [String: String], server: RPCServer? = nil) -> XPathObject {
        if let server = server {
            return contractElement.xpath("address[@network='\(String(server.chainID))']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        } else {
            return contractElement.xpath("address".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        }
    }

    fileprivate static func getAttributeTypeElements(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String]) -> XPathObject {
        return root.xpath("/token/attribute-types/attribute-type".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    static func getOriginElement(fromAttributeTypeElement attributeTypeElement: XMLElement, namespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        return attributeTypeElement.at_xpath("origin".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    static func getNameElement(fromAttributeTypeElement attributeTypeElement: XMLElement, namespacePrefix: String, namespaces: [String: String], lang: String) -> XMLElement? {
        if let nameElement = attributeTypeElement.at_xpath("name[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces) {
            return nameElement
        } else {
            let fallback = attributeTypeElement.at_xpath("name[1]".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
            return fallback
        }
    }

    static func getBitMaskFrom(fromAttributeTypeElement attributeTypeElement: XMLElement, namespacePrefix: String, namespaces: [String: String]) -> BigUInt? {
        guard let originElement = getOriginElement(fromAttributeTypeElement: attributeTypeElement, namespacePrefix: namespacePrefix, namespaces: namespaces) else { return nil }
        guard let bitmask = originElement["bitmask"] else { return nil }
        return BigUInt(bitmask, radix: 16)
    }

    fileprivate static func getFunctionElement(fromOriginElement originElement: XMLElement, namespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        return originElement.at_xpath("function".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    fileprivate static func getNameElement(fromTokenElement tokenElement: XMLElement?, namespacePrefix: String, namespaces: [String: String], lang: String) -> XMLElement? {
        guard let tokenElement = tokenElement else { return nil }
        //`1` in XPath selects the first node, not `0`
        let nameElementMatchingLanguage = tokenElement.at_xpath("name[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        if nameElementMatchingLanguage != nil {
            return nameElementMatchingLanguage
        } else {
            let fallback = tokenElement.at_xpath("name[1]".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
            return fallback
        }
    }

    fileprivate static func getNameElementForCollective(fromTokenElement tokenElement: XMLElement?, namespacePrefix: String, namespaces: [String: String], lang: String) -> XMLElement? {
        guard let tokenElement = tokenElement else { return nil }
        //`1` in XPath selects the first node, not `0`
        let nameElementMatchingLanguage = tokenElement.at_xpath("name[@xml:lang='\(lang)' and @form='collective']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        if nameElementMatchingLanguage != nil {
            return nameElementMatchingLanguage
        } else {
            return getNameElement(fromTokenElement: tokenElement, namespacePrefix: namespacePrefix, namespaces: namespaces, lang: lang)
        }
    }

    fileprivate static func getKeyNameElement(fromRoot root: XMLDocument, namespacePrefix: String, signatureNamespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        let xpath = "/token".addToXPath(namespacePrefix: namespacePrefix) + "/Signature/KeyInfo/KeyName".addToXPath(namespacePrefix: signatureNamespacePrefix)
        return root.at_xpath(xpath, namespaces: namespaces)
    }

    static func getInputsElement(fromFunctionElement functionElement: XMLElement, namespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        return functionElement.at_xpath("inputs".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    static func getInputs(fromInputsElement inputsElement: XMLElement) -> XPathObject {
        return inputsElement.xpath("*")
    }

    static func getMappingOptionValue(fromAttributeElement attributeElement: XMLElement, namespacePrefix: String, namespaces: [String: String], withKey key: String, forLang lang: String) -> String? {
        guard let optionElement = attributeElement.at_xpath("origin/mapping/option[@key='\(key)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces) else { return nil }
        if let valueForLang = optionElement.at_xpath("value[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)?.text {
            return valueForLang
        } else {
            //`1` selects the first node, not `0`
            let fallback = optionElement.at_xpath("value[1]".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)?.text
            return fallback
        }
    }

     static func getTbmlIntroductionElement(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String], forLang lang: String) -> XMLElement? {
        return root.at_xpath("/token/appearance/introduction[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    fileprivate static func getTokenScriptTokenInstanceActionElements(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String]) -> XPathObject {
        return root.xpath("/token/cards/action".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    static func getTokenScriptTokenViewIconifiedHtmlElement(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String], forLang lang: String) -> XMLElement? {
        if let element = root.at_xpath("/token/cards/token-card/view-iconified[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces) {
            return element
        } else {
            return root.at_xpath("/token/cards/token-card/view-iconified[1]".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        }
    }

    static func getTokenScriptTokenViewIconifiedStyleElement(fromRoot root: XMLDocument, namespacePrefix: String, xhtmlNamespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        guard let element = root.at_xpath("/token/cards/token-card".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces) else { return nil }
        return element.at_xpath("style".addToXPath(namespacePrefix: xhtmlNamespacePrefix), namespaces: namespaces)
    }

    static func getTokenScriptTokenViewHtmlElement(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String], forLang lang: String) -> XMLElement? {
        if let element = root.at_xpath("/token/cards/token-card/view[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces) {
            return element
        } else {
            return root.at_xpath("/token/cards/token-card/view[1]".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        }
    }

    fileprivate static func getNameElement(fromActionElement actionElement: Searchable, namespacePrefix: String, namespaces: [String: String], forLang lang: String) -> XMLElement? {
        if let element = actionElement.at_xpath("name[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces) {
            return element
        } else {
            return actionElement.at_xpath("name[1]".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        }
    }

    fileprivate static func getViewElement(fromActionElement actionElement: Searchable, namespacePrefix: String, namespaces: [String: String], forLang lang: String) -> XMLElement? {
        if let element = actionElement.at_xpath("view[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces) {
            return element
        } else {
            return actionElement.at_xpath("view[1]".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        }
    }

    static func getTokenScriptActionViewStyleElement(fromRoot root: XMLDocument, namespacePrefix: String, xhtmlNamespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        guard let element = root.at_xpath("/token/cards/action".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces) else { return nil }
        return element.at_xpath("style".addToXPath(namespacePrefix: xhtmlNamespacePrefix), namespaces: namespaces)
    }
}
