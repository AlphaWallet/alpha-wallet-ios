//
//  BalanceHelper.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt

class TokenAdaptor {
    private let token: TokenObject
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: EventsDataStoreProtocol

    init(token: TokenObject, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol) {
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
    }

    //`sourceFromEvents`: We'll usually source from events if available, except when we are actually using this func to create the filter to fetch the events
    public func getTokenHolders(forWallet account: Wallet, isSourcedFromEvents: Bool = true) -> [TokenHolder] {
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            return getNotSupportedByNonFungibleJsonTokenHolders(forWallet: account)
        case .erc721:
            let tokenType = NonFungibleFromJsonSupportedTokenHandling(token: token)
            switch tokenType {
            case .supported:
                return getSupportedByNonFungibleJsonTokenHolders(forWallet: account, isSourcedFromEvents: isSourcedFromEvents)
            case .notSupported:
                return getNotSupportedByNonFungibleJsonTokenHolders(forWallet: account)
            }
        }
    }

    private func getNotSupportedByNonFungibleJsonTokenHolders(forWallet account: Wallet) -> [TokenHolder] {
        let balance = token.balance
        var tokens = [Token]()
        switch token.type {
        case .erc875, .erc721ForTickets, .erc721, .nativeCryptocurrency:
            for (index, item) in balance.enumerated() {
                //id is the value of the bytes32 token
                let id = item.balance
                guard isNonZeroBalance(id, tokenType: token.type) else { continue }
                if let tokenInt = BigUInt(id.drop0x, radix: 16) {
                    let server = self.token.server
                    //TODO Event support, if/when designed, for non-OpenSea. Probably need `distinct` or something to that effect
                    let token = getToken(name: self.token.name, symbol: self.token.symbol, forTokenIdOrEvent: .tokenId(tokenId: tokenInt), index: UInt16(index), inWallet: account, server: server)
                    tokens.append(token)
                }
            }
            return bundle(tokens: tokens)
        case .erc20:
            //For fungibles, we have to get 1 token even if the balance.count is 0. Maybe we check value? No, even if value is 0, there might be attributes
            let tokenInt: BigUInt = .init(1)
            let index = 0

            let server = self.token.server
            //TODO Event support, if/when designed, for non-OpenSea. Probably need `distinct` or something to that effect
            let token = getToken(name: self.token.name, symbol: self.token.symbol, forTokenIdOrEvent: .tokenId(tokenId: tokenInt), index: UInt16(index), inWallet: account, server: server)
            tokens.append(token)
            return bundle(tokens: tokens)
        }
    }

    private func getSupportedByNonFungibleJsonTokenHolders(forWallet account: Wallet, isSourcedFromEvents: Bool) -> [TokenHolder] {
        let balance = token.balance
        var tokens = [Token]()
        for item in balance {
            let jsonString = item.balance
            if let token = getTokenForNonFungible(forJSONString: jsonString, inWallet: account, server: self.token.server, isSourcedFromEvents: isSourcedFromEvents) {
                tokens.append(token)
            }
        }
        return bundle(tokens: tokens)
    }

    func bundle(tokens: [Token]) -> [TokenHolder] {
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc875:
            if !tokens.isEmpty && tokens[0].isSpawnableMeetupContract {
                return tokens.sorted { $0.id < $1.id }.map { getTokenHolder(for: [$0]) }
            } else {
                break
            }
        case .erc721, .erc721ForTickets:
            return tokens.map { getTokenHolder(for: [$0]) }
        }
        var tokenHolders: [TokenHolder] = []
        let groups = groupTokensByFields(tokens: tokens)
        for each in groups {
            let results = breakBundlesFurtherToHaveContinuousSeatRange(tokens: each)
            for tokens in results {
                tokenHolders.append(getTokenHolder(for: tokens))
            }
        }
        tokenHolders = sortBundlesUpcomingFirst(bundles: tokenHolders)
        return tokenHolders
    }

    private func sortBundlesUpcomingFirst(bundles: [TokenHolder]) -> [TokenHolder] {
        return bundles.sorted {
            let d0 = $0.values["time"]?.generalisedTimeValue ?? GeneralisedTime()
            let d1 = $1.values["time"]?.generalisedTimeValue ?? GeneralisedTime()
            return d0 < d1
        }
    }

    //If sequential or have the same seat number, add them together
    ///e.g 21, 22, 25 is broken up into 2 bundles: 21-22 and 25.
    ///e.g 21, 21, 22, 25 is broken up into 2 bundles: (21,21-22) and 25.
    private func breakBundlesFurtherToHaveContinuousSeatRange(tokens: [Token]) -> [[Token]] {
        let tokens = tokens.sorted {
            let s0 = $0.values["numero"]?.intValue ?? 0
            let s1 = $1.values["numero"]?.intValue ?? 0
            return s0 <= s1
        }
        return tokens.reduce([[Token]]()) { results, token in
            var results = results
            if var previousRange = results.last, let previousToken = previousRange.last, (previousToken.seatId + 1 == token.seatId || previousToken.seatId == token.seatId) {
                previousRange.append(token)
                let _ = results.popLast()
                results.append(previousRange)
            } else {
                results.append([token])
            }
            return results
        }
    }

    ///Group by the properties used in the hash. We abuse a dictionary to help with grouping
    private func groupTokensByFields(tokens: [Token]) -> Dictionary<String, [Token]>.Values {
        var dictionary = [String: [Token]]()
        for each in tokens {
            let city = each.values["locality"]?.stringValue ?? "N/A"
            let venue = each.values["venue"]?.stringValue ?? "N/A"
            let date = each.values["time"]?.generalisedTimeValue ?? GeneralisedTime()
            let countryA = each.values["countryA"]?.stringValue ?? ""
            let countryB = each.values["countryB"]?.stringValue ?? ""
            let match = each.values["match"]?.intValue ?? 0
            let category = each.values["category"]?.stringValue ?? "N/A"

            let hash = "\(city),\(venue),\(date),\(countryA),\(countryB),\(match),\(category)"
            var group = dictionary[hash] ?? []
            group.append(each)
            dictionary[hash] = group
        }
        return dictionary.values
    }

    //TODO pass lang into here
    private func getToken(name: String, symbol: String, forTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, index: UInt16, inWallet account: Wallet, server: RPCServer) -> Token {
        XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).getToken(name: name, symbol: symbol, fromTokenIdOrEvent: tokenIdOrEvent, index: index, inWallet: account, server: server, tokenType: token.type)
    }

    private func getTokenForNonFungible(forJSONString jsonString: String, inWallet account: Wallet, server: RPCServer, isSourcedFromEvents: Bool) -> Token? {
        guard let data = jsonString.data(using: .utf8), let nonFungible = nonFungible(fromJsonData: data) else { return nil }

        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let event: EventInstance?
        if isSourcedFromEvents, let attributeWithEventSource = xmlHandler.attributesWithEventSource.first, let eventFilter = attributeWithEventSource.eventOrigin?.eventFilter, let eventName = attributeWithEventSource.eventOrigin?.eventName, let eventContract = attributeWithEventSource.eventOrigin?.contract {
            let filterName = eventFilter.name
            let filterValue: String
            if let implicitAttribute = EventSourceCoordinator.convertToImplicitAttribute(string: eventFilter.value) {
                switch implicitAttribute {
                case .tokenId:
                    filterValue = eventFilter.value.replacingOccurrences(of: "${tokenId}", with: nonFungible.tokenId)
                case .ownerAddress:
                    filterValue = eventFilter.value.replacingOccurrences(of: "${ownerAddress}", with: account.address.eip55String)
                case .label, .contractAddress, .symbol:
                    filterValue = eventFilter.value
                }
            } else {
                filterValue = eventFilter.value
            }
            let eventsFromDatabase = eventsDataStore.getMatchingEvents(forContract: eventContract, tokenContract: token.contractAddress, server: server, eventName: eventName, filterName: filterName, filterValue: filterValue)
            event = eventsFromDatabase.first
        } else {
            event = nil
        }
        let tokenId = BigUInt(nonFungible.tokenId) ?? BigUInt(0)
        let tokenIdOrEvent: TokenIdOrEvent
        if let eventNonOptional = event {
            tokenIdOrEvent = .event(tokenId: tokenId, event: eventNonOptional)
        } else {
            tokenIdOrEvent = .tokenId(tokenId: tokenId)
        }
        var values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: tokenIdOrEvent, server: server, account: account)
        values["tokenId"] = .init(directoryString: nonFungible.tokenId)
        values["name"] = .init(directoryString: nonFungible.name)
        values["description"] = .init(directoryString: nonFungible.description)
        values["imageUrl"] = .init(directoryString: nonFungible.imageUrl)
        values["contractImageUrl"] = .init(directoryString: nonFungible.contractImageUrl)
        values["thumbnailUrl"] = .init(directoryString: nonFungible.thumbnailUrl)
        values["externalLink"] = .init(directoryString: nonFungible.externalLink)
        values["backgroundColor"] = nonFungible.backgroundColor.flatMap { .init(directoryString: $0) }
        values["traits"] = .init(openSeaTraits: nonFungible.traits)

        let status: Token.Status
        let cryptoKittyGenerationWhenDataNotAvailable = "-1"
        if let generation = nonFungible.generationTrait, generation.value == cryptoKittyGenerationWhenDataNotAvailable {
            status = .availableButDataUnavailable
        } else {
            status = .available
        }
        return Token(
                tokenIdOrEvent: tokenIdOrEvent,
                tokenType: TokenType.erc721,
                index: 0,
                name: nonFungible.contractName,
                symbol: "",
                status: status,
                values: values
        )
    }

    private func getTokenHolder(for tokens: [Token]) -> TokenHolder {
        return TokenHolder(
                tokens: tokens,
                contractAddress: token.contractAddress,
                hasAssetDefinition: XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore).hasAssetDefinition
        )
    }

}

extension Token {
    //TODO Convenience-only. (Look for references). Should remove once we generalize things further and not hardcode the use of seatId
    var seatId: Int {
        return values["numero"]?.intValue.flatMap { Int($0) }  ?? 0
    }
}
