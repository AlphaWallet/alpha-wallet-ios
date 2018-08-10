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

//  Interface to extract data from non fungible token

private class PrivateXMLHandler {
    private let xml: XML.Accessor
    let contractAddress: String
    lazy var contract = xml["token"]["contract"].getElement(attributeName: "type", attributeValue: "holding", fallbackToFirst: true)
    lazy var fields = extractFields()
    private let isOfficial: Bool

    init(contract: String) {
        contractAddress = contract.add0x.lowercased()
        let assetDefinitionStore = AssetDefinitionStore()
        xml = try! XML.parse(assetDefinitionStore[contract] ?? "")
        isOfficial = assetDefinitionStore.isOfficial(contract: contract)
    }

    func getFifaInfoForTicket(tokenId tokenBytes32: BigUInt, index: UInt16) -> Ticket {
        guard tokenBytes32 != 0 else { return .empty }
        let lang = getLang()
        var values = [String: AssetAttributeValue]()
        for (name, attribute) in fields {
            let value = attribute.extract(from: tokenBytes32)
            values[name] = value
        }

        return Ticket(
                id: String(tokenBytes32, radix: 16),
                index: index,
                name: getName(lang: lang),
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

    func getName(lang: String) -> String {
        if let name = contract?["name"].getElementWithLangAttribute(equals: lang)?.text {
            return name
        }
        return "N/A"
    }
    
    func getLang() -> String {
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

    func getFifaInfoForTicket(tokenId tokenBytes32: BigUInt, index: UInt16) -> Ticket {
        return privateXMLHandler.getFifaInfoForTicket(tokenId: tokenBytes32, index: index)
    }

    func getName(lang: String) -> String {
        return privateXMLHandler.getName(lang: lang)
    }

    func getLang() -> String {
        return privateXMLHandler.getLang()
    }

    func isVerified(for server: RPCServer) -> Bool {
        return privateXMLHandler.isVerified(for: server)
    }
}
