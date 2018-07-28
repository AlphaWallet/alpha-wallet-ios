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
        //check if leading or trailing zeros
        let tokenId = tokenBytes32
        guard tokenId != 0 else { return .empty }
        let lang = getLang()
        let tokenHex = MarketQueueHandler.bytesToHexa(tokenBytes32.serialize().bytes)

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

    //kkk read from XML
    func getStaticImageURLFormat() -> String? {
        if contractAddress.sameContract(as: "0x06012c8cf97BEaD5deAe237070F9587f8E7A266d") {
            return "https://img.cn.cryptokitties.co/#{contract_address}/#{id}.svg"
        } else {
            return nil
        }
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

    //kkk can also have supportsStaticAssetImage() ?
    func getStaticImageURLFormat() -> String? {
        return privateXMLHandler.getStaticImageURLFormat()
    }

    func getStaticImageURL(forId id: String) -> String? {
        guard let format = getStaticImageURLFormat() else { return nil }
        return format
                .replacingOccurrences(of: "#{contract_address}", with: privateXMLHandler.contractAddress)
                .replacingOccurrences(of: "#{id}", with: id)
    }
}
