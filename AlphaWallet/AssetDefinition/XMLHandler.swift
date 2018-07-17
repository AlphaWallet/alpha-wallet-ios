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
    //TODO do we always want the first one?
    lazy var contract = xml["token"]["contract"][0]
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
        xml = try! XML.parse(assetDefinitionStore[contract] ?? "")
        isOfficial = assetDefinitionStore.isOfficial(contract: contract)
        signatureNamespace = PrivateXMLHandler.discoverSignatureNamespace(xml: xml)
    }

    func getFifaInfoForTicket(tokenId tokenBytes32: BigUInt, index: UInt16) -> Ticket {
        //check if leading or trailing zeros
        let tokenId = tokenBytes32
        guard tokenId != 0 else { return .empty }
        let lang = getLang()
        let tokenHex = MarketQueueHandler.bytesToHexa(tokenBytes32.serialize().bytes)

        //TODO should check for nil and handle rather than default to any value in this class. Or maybe the asset definition XML is missing. Otherwise, it should be returning a reasonable default already
        let locality: String = fields["locality"]?.extract(from: tokenHex) ?? "N/A"
        let venue: String = fields["venue"]?.extract(from: tokenHex) ?? "N/A"
        let time: GeneralisedTime = fields["time"]?.extract(from: tokenHex) ?? .init()
        let countryA: String = fields["countryA"]?.extract(from: tokenHex) ?? ""
        let countryB: String = fields["countryB"]?.extract(from: tokenHex) ?? ""
        let match: Int = fields["match"]?.extract(from: tokenHex) ?? 0
        let category: String = fields["category"]?.extract(from: tokenHex) ?? "N/A"
        let numero: Int = fields["numero"]?.extract(from: tokenHex) ?? 0

        return Ticket(
                id: MarketQueueHandler.bytesToHexa(tokenId.serialize().array),
                index: index,
                city: locality,
                name: getName(lang: lang),
                venue: venue,
                match: match,
                date: time,
                seatId: numero,
                category: category,
                countryA: countryA,
                countryB: countryB
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
            if let id = e.attributes["id"], case let .singleElement(element) = e {
                fields[id] = AssetAttribute(attribute: element, lang: lang)
            }
        }
        return fields
    }

    func getName(lang: String) -> String {
        if let name = contract["name"].getElementWithLangAttribute(equals: lang)?.text {
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

    func getFifaInfoForTicket(tokenId tokenBytes32: BigUInt, index: UInt16) -> Ticket {
        return privateXMLHandler.getFifaInfoForTicket(tokenId: tokenBytes32, index: index)
    }

    func getName(lang: String) -> String {
        return privateXMLHandler.getName(lang: lang)
    }

    func getLang() -> String {
        return privateXMLHandler.getLang()
    }

    func getIssuer() -> String {
        return privateXMLHandler.getIssuer()
    }

    func isVerified(for server: RPCServer) -> Bool {
        return privateXMLHandler.isVerified(for: server)
    }
}
