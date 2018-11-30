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

//  Interface to extract data from non fungible token
private class PrivateXMLHandler {
    private static let emptyXMLString = "<tbml:token xmlns:tbml=\"http://attestation.id/ns/tbml\"></tbml:token>"
    private static let emptyXML = try! Kanna.XML(xml: emptyXMLString, encoding: .utf8)

    private let xml: XMLDocument
    private let rootNamespacePrefix = "tb:"
    private let signatureNamespacePrefix = "ds:"
    private let namespaces = [
        "tb": "http://attestation.id/ns/tbml",
        "ds": "http://www.w3.org/2000/09/xmldsig#"
    ]
    private let contractAddress: String
    private lazy var fields = extractFields()
    private let isOfficial: Bool

    private var contractElement: XMLElement? {
        return XMLHandler.getContractElement(fromRoot: xml, namespacePrefix: rootNamespacePrefix, namespaces: namespaces)
    }

    let hasAssetDefinition: Bool

    init(contract: String, assetDefinitionStore store: AssetDefinitionStore?) {
        contractAddress = contract.add0x.lowercased()
        let assetDefinitionStore = store ?? AssetDefinitionStore()
        let xmlString = assetDefinitionStore[contract]
        hasAssetDefinition = xmlString != nil
        if let xmlString = xmlString {
            xml = (try? Kanna.XML(xml: xmlString, encoding: .utf8)) ?? PrivateXMLHandler.emptyXML
        } else {
            xml = PrivateXMLHandler.emptyXML
        }
        isOfficial = assetDefinitionStore.isOfficial(contract: contract)
    }

    func getToken(name: String, fromTokenId tokenBytes32: BigUInt, index: UInt16, config: Config, callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator?) -> Token {
        guard tokenBytes32 != 0 else { return .empty }
        var values = [String: AssetAttributeValue]()
        for (name, attribute) in fields {
            let value = attribute.extract(from: tokenBytes32, ofContract: contractAddress, config: config, callForAssetAttributeCoordinator: callForAssetAttributeCoordinator)
            values[name] = value
        }

        return Token(
                id: tokenBytes32,
                index: index,
                name: name,
                status: .available,
                values: values
        )
    }

    func isVerified(for server: RPCServer) -> Bool {
        guard isOfficial else { return false }

        guard let contractElement = contractElement else { return false }
        guard let addressElement = XMLHandler.getAddressElement(fromContractElement: contractElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, server: server) else { return false }
        guard let contractInXML = addressElement.text else { return false }
        return contractInXML.sameContract(as: contractAddress)
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
                fields[id] = AssetAttribute(attribute: each, functionElement: functionElement, rootNamespacePrefix: rootNamespacePrefix, namespaces: namespaces)
            }
        }
        return fields
    }

    func getName() -> String {
        let lang = getLang()
        if  let nameElement = XMLHandler.getNameElement(fromContractElement: contractElement, namespacePrefix: rootNamespacePrefix, namespaces: namespaces, lang: lang), let name = nameElement.text {
            return name
        } else {
            return "N/A"
        }
    }

    func getTokenTypeName(_ type: SingularOrPlural = .plural, titlecase: TitlecaseOrNot = .titlecase) -> String {
        //TODO should generalize this
        if contractAddress.sameContract(as: Constants.cryptoKittiesContractAddress) {
            switch titlecase {
            case .titlecase:
                return R.string.localizable.cryptokittiesTitlecase()
            case .notTitlecase:
                return R.string.localizable.cryptokittiesLowercase()
            }
        }

        let name = getName()
        if name == "N/A" {
            switch type {
            case .singular:
                switch titlecase {
                case .titlecase:
                    return R.string.localizable.tokenTitlecase()
                case .notTitlecase:
                    return R.string.localizable.tokenLowercase()
                }
            case .plural:
                switch titlecase {
                case .titlecase:
                    return R.string.localizable.tokensTitlecase()
                case .notTitlecase:
                    return R.string.localizable.tokensLowercase()
                }
            }
        } else {
            //TODO be smart with lowercase and title case
            return name
        }
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
}

/// This class delegates all the functionality to a singleton of the actual XML parser. 1 for each contract. So we just parse the XML file 1 time only for each contract
public class XMLHandler {
    static var callForAssetAttributeCoordinator: CallForAssetAttributeCoordinator?
    fileprivate static var xmlHandlers: [String: PrivateXMLHandler] = [:]
    private let privateXMLHandler: PrivateXMLHandler

    var hasAssetDefinition: Bool {
        return privateXMLHandler.hasAssetDefinition
    }

    init(contract: String, assetDefinitionStore: AssetDefinitionStore? = nil) {
        let contract = contract.add0x.lowercased()
        if let handler = XMLHandler.xmlHandlers[contract] {
            privateXMLHandler = handler
        } else {
            privateXMLHandler = PrivateXMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore)
            XMLHandler.xmlHandlers[contract] = privateXMLHandler
        }
    }

    public static func invalidate(forContract contract: String) {
        xmlHandlers[contract.add0x.lowercased()] = nil
    }

    public static func invalidateAllContracts() {
        xmlHandlers.removeAll()
    }

    func getToken(name: String, fromTokenId tokenBytes32: BigUInt, index: UInt16, config: Config) -> Token {
        return privateXMLHandler.getToken(name: name, fromTokenId: tokenBytes32, index: index, config: config, callForAssetAttributeCoordinator: XMLHandler.callForAssetAttributeCoordinator)
    }

    func getName() -> String {
        return privateXMLHandler.getName()
    }

    /// Expected to return names like "cryptokitties", "token" that are specified in the asset definition. If absent, fallback to "tokens"
    func getTokenTypeName(_ type: SingularOrPlural = .plural, titlecase: TitlecaseOrNot = .titlecase) -> String {
        return privateXMLHandler.getTokenTypeName(type, titlecase: titlecase)
    }

    func getIssuer() -> String {
        return privateXMLHandler.getIssuer()
    }

    func isVerified(for server: RPCServer) -> Bool {
        return privateXMLHandler.isVerified(for: server)
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
    fileprivate static func getContractElement(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        return root.at_xpath("/token/contract".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    fileprivate static func getAddressElement(fromContractElement contractElement: Searchable, namespacePrefix: String, namespaces: [String: String], server: RPCServer) -> XMLElement? {
        return contractElement.at_xpath("address[@network='\(String(server.chainID))']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    fileprivate static func getAttributeTypeElements(fromRoot root: XMLDocument, namespacePrefix: String, namespaces: [String: String]) -> XPathObject {
        return root.xpath("/token/attribute-types/attribute-type".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    static func getOriginElement(fromAttributeTypeElement attributeTypeElement: XMLElement, namespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        return attributeTypeElement.at_xpath("origin".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    static func getBitMaskFrom(fromAttributeTypeElement attributeTypeElement: XMLElement, namespacePrefix: String, namespaces: [String: String]) -> BigUInt? {
        guard let originElement = getOriginElement(fromAttributeTypeElement: attributeTypeElement, namespacePrefix: namespacePrefix, namespaces: namespaces) else { return nil }
        guard let bitmask = originElement["bitmask"] else { return nil }
        return BigUInt(bitmask, radix: 16)
    }

    fileprivate static func getFunctionElement(fromOriginElement originElement: XMLElement, namespacePrefix: String, namespaces: [String: String]) -> XMLElement? {
        return originElement.at_xpath("function".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
    }

    fileprivate static func getNameElement(fromContractElement contractElement: XMLElement?, namespacePrefix: String, namespaces: [String: String], lang: String) -> XMLElement? {
        guard let contractElement = contractElement else { return nil }
        //`1` in XPath selects the first node, not `0`
        let nameElementMatchingLanguage = contractElement.at_xpath("name[@xml:lang='\(lang)']".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
        if nameElementMatchingLanguage != nil {
            return nameElementMatchingLanguage
        } else {
            let fallback = contractElement.at_xpath("name[1]".addToXPath(namespacePrefix: namespacePrefix), namespaces: namespaces)
            return fallback
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
}
