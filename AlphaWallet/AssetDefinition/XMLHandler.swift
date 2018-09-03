//
//  XMLHandler.swift
//  AlphaWallet
//
//  Created by James Sangalli on 11/4/18.
//

import Foundation
import SwiftyXMLParser
import BigInt
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
    private let xml: XML.Accessor
    let contractAddress: String
    lazy var contract = xml["token"]["contract"].getElement(attributeName: "type", attributeValue: "holding", fallbackToFirst: true)
    lazy var fields = extractFields()
    private let isOfficial: Bool
    private let signatureNamespace: String
    private var signatureNamespacePrefix: String {
        if signatureNamespace.isEmpty {
            return ""
        } else {
            return "\(signatureNamespace):"
        }
    }

    init(contract: String) {
        contractAddress = contract.add0x.lowercased()
        let assetDefinitionStore = AssetDefinitionStore()
        //We use a try? for the first parse() instead of try! to avoid the very unlikely chance that it will crash. We fallback to an empty XML just like if we haven't downloaded it yet
        xml = (try? XML.parse(assetDefinitionStore[contract] ?? "")) ?? (try! XML.parse(""))
        isOfficial = assetDefinitionStore.isOfficial(contract: contract)
        signatureNamespace = PrivateXMLHandler.discoverSignatureNamespace(xml: xml)
    }

    func getToken(fromTokenId tokenBytes32: BigUInt, index: UInt16) -> Token {
        guard tokenBytes32 != 0 else { return .empty }
        var values = [String: AssetAttributeValue]()
        for (name, attribute) in fields {
            let value = attribute.extract(from: tokenBytes32)
            values[name] = value
        }

        return Token(
                id: tokenBytes32,
                index: index,
                name: getName(),
                values: values
        )
    }

    func isVerified(for server: RPCServer) -> Bool {
        guard isOfficial else { return false }
        let contractElement = xml["token"]["contract"].getElement(attributeName: "id", attributeValue: "holding_contract")
        let addressElement = contractElement?["address"].getElement(attributeName: "network", attributeValue: String(server.chainID))
        guard let contractInXML = addressElement?.text else { return false }
        return contractInXML.sameContract(as: contractAddress)
    }

    private func extractFields() -> [String: AssetAttribute] {
        let lang = getLang()
        var fields = [String: AssetAttribute]()
        for e in xml["token"]["attribute-types"]["attribute-type"] {
            if let id = e.attributes["id"], case let .singleElement(element) = e, XML.Accessor(element)["origin"].attributes["as"] != nil {
                fields[id] = AssetAttribute(attribute: element, lang: lang)
            }
        }
        return fields
    }

    func getName() -> String {
        let lang = getLang()
        if let name = contract?["name"].getElementWithLangAttribute(equals: lang)?.text {
            if contractAddress.sameContract(as: Constants.ticketContractAddress) || contractAddress.sameContract(as: Constants.ticketContractAddressRopsten ) {
                return "\(Constants.fifaWorldCup2018TokenNamePrefix) \(name)"
            }
            return name
        }
        return "N/A"
    }

    func getTokenTypeName(_ type: SingularOrPlural = .plural, titlecase: TitlecaseOrNot = .titlecase) -> String {
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
        if let issuer = xml["token"]["\(signatureNamespacePrefix)Signature"]["\(signatureNamespacePrefix)KeyInfo"]["\(signatureNamespacePrefix)KeyName"].text {
            return issuer
        }
        return ""
    }

    private static func discoverSignatureNamespace(xml: XML.Accessor) -> String {
        if case let .singleElement(element) = xml["token"] {
            let children: [XML.Element] = element.childElements
            for each in children {
                if each.name == "Signature" {
                    return ""
                } else if each.name.hasSuffix(":Signature") {
                    return String(each.name.split(separator: ":")[0])
                }
            }
        }
        return ""
    }
}

/// This class delegates all the functionality to a singleton of the actual XML parser. 1 for each contract. So we just parse the XML file 1 time only for each contract
public class XMLHandler {
    fileprivate static var xmlHandlers: [String: PrivateXMLHandler] = [:]
    private let privateXMLHandler: PrivateXMLHandler

    init(contract: String) {
        let contract = contract.add0x.lowercased()
        if let handler = XMLHandler.xmlHandlers[contract] {
            privateXMLHandler = handler
        } else {
            privateXMLHandler = PrivateXMLHandler(contract: contract)
            XMLHandler.xmlHandlers[contract] = privateXMLHandler
        }
    }

    public static func invalidate(forContract contract: String) {
        xmlHandlers[contract.add0x.lowercased()] = nil
    }

    func getToken(fromTokenId tokenBytes32: BigUInt, index: UInt16) -> Token {
        return privateXMLHandler.getToken(fromTokenId: tokenBytes32, index: index)
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
