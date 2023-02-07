//
//  TokenAdaptor.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import AlphaWalletOpenSea
import BigInt
import Combine

public protocol TokenHolderState {
    func tokenHolders(for token: TokenIdentifiable) -> [TokenHolder]
    func tokenHoldersPublisher(for token: TokenIdentifiable) -> AnyPublisher<[TokenHolder], Never>
    func tokenHolderPublisher(for token: TokenIdentifiable, tokenId: TokenId) -> AnyPublisher<TokenHolder?, Never>
}

extension TokenHolderState {
    public func tokenHolderPublisher(for token: TokenIdentifiable, tokenId: TokenId) -> AnyPublisher<TokenHolder?, Never> {
        tokenHoldersPublisher(for: token)
            .map { tokenHolders in
                switch token.type {
                case .erc721, .erc875, .erc721ForTickets:
                    return tokenHolders.first { $0.tokens[0].id == tokenId }
                case .erc1155:
                    return tokenHolders.first(where: { $0.tokens.contains(where: { $0.id == tokenId }) })
                case .nativeCryptocurrency, .erc20:
                    return nil
                }
            }.eraseToAnyPublisher()
    }
}

extension TokenHolder: ObservableObject { }

extension TokenScriptSupportable {

    public func getTokenHolders(assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, forWallet account: Wallet, isSourcedFromEvents: Bool = true) -> [TokenHolder] {
        let tokenAdaptor = TokenAdaptor(token: self, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore)
        return tokenAdaptor.getTokenHolders(forWallet: account, isSourcedFromEvents: isSourcedFromEvents)
    }

    /// Generates token holder for fungible token, with id 1
    public func getTokenHolder(assetDefinitionStore: AssetDefinitionStore, forWallet account: Wallet) -> TokenHolder {
        //TODO id 1 for fungibles. Might come back to bite us?
        let hardcodedTokenIdForFungibles = BigUInt(1)
        let xmlHandler = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore)
            //TODO Event support, if/when designed for fungibles
        let values = xmlHandler.resolveAttributesBypassingCache(
            withTokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles),
            server: server,
            account: account,
            assetDefinitionStore: assetDefinitionStore)

        let subscribablesForAttributeValues = values.values
        let allResolved = subscribablesForAttributeValues.allSatisfy { $0.subscribableValue?.value != nil }

        let token = TokenScript.Token(tokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), tokenType: type, index: 0, name: name, symbol: symbol, status: .available, values: values)
        let tokenHolder = TokenHolder(tokens: [token], contractAddress: contractAddress, hasAssetDefinition: true)

        if allResolved {
            //no-op
        } else {
            for each in subscribablesForAttributeValues {
                guard let subscribable = each.subscribableValue else { continue }
                subscribable.subscribe { [weak tokenHolder] _ in
                    tokenHolder?.objectWillChange.send()
                }
            }
        }

        return tokenHolder
    }
}

public class TokenAdaptor {
    private let token: TokenScriptSupportable
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let xmlHandler: XMLHandler

    public init(token: TokenScriptSupportable,
                assetDefinitionStore: AssetDefinitionStore,
                eventsDataStore: NonActivityEventsDataStore) {

        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
    }

    //`sourceFromEvents`: We'll usually source from events if available, except when we are actually using this func to create the filter to fetch the events
    public func getTokenHolders(forWallet account: Wallet, isSourcedFromEvents: Bool = true) -> [TokenHolder] {
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            return getNotSupportedByNonFungibleJsonTokenHolders(forWallet: account)
        case .erc721, .erc1155:
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
        var tokens = [TokenScript.Token]()
        switch token.type {
        case .erc875, .erc721ForTickets, .erc721, .erc1155, .nativeCryptocurrency:
            for (index, item) in token.balanceNft.enumerated() {
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
        var tokens = [TokenScript.Token]()
        for nonFungibleBalance in token.balanceNft.compactMap({ $0.nonFungibleBalance }) {
            if let token = getTokenForNonFungible(nonFungible: nonFungibleBalance, inWallet: account, server: self.token.server, isSourcedFromEvents: isSourcedFromEvents, tokenType: self.token.type) {
                tokens.append(token)
            }
        }
        return bundle(tokens: tokens)
    }

    //NOTE: internal for testing purposes
    public func bundleTestsOnly(tokens: [TokenScript.Token]) -> [TokenHolder] {
        bundle(tokens: tokens)
    }

    private func bundle(tokens: [TokenScript.Token]) -> [TokenHolder] {
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc875:
            if !tokens.isEmpty && tokens[0].isSpawnableMeetupContract {
                return tokens.sorted { $0.id < $1.id }.map { getTokenHolder(for: [$0]) }
            } else {
                break
            }
        case .erc721, .erc721ForTickets, .erc1155:
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
            let d0 = $0.values.timeGeneralisedTimeValue ?? GeneralisedTime()
            let d1 = $1.values.timeGeneralisedTimeValue ?? GeneralisedTime()
            return d0 < d1
        }
    }

    //If sequential or have the same seat number, add them together
    ///e.g 21, 22, 25 is broken up into 2 bundles: 21-22 and 25.
    ///e.g 21, 21, 22, 25 is broken up into 2 bundles: (21,21-22) and 25.
    private func breakBundlesFurtherToHaveContinuousSeatRange(tokens: [TokenScript.Token]) -> [[TokenScript.Token]] {
        let tokens = tokens.sorted {
            let s0 = $0.values.numeroIntValue ?? 0
            let s1 = $1.values.numeroIntValue ?? 0
            return s0 <= s1
        }
        return tokens.reduce([[TokenScript.Token]]()) { results, token in
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
    private func groupTokensByFields(tokens: [TokenScript.Token]) -> Dictionary<String, [TokenScript.Token]>.Values {
        var dictionary = [String: [TokenScript.Token]]()
        for each in tokens {
            let city = each.values.localityStringValue ?? "N/A"
            let venue = each.values.venueStringValue ?? "N/A"
            let date = each.values.timeGeneralisedTimeValue ?? GeneralisedTime()
            let countryA = each.values.countryAStringValue ?? ""
            let countryB = each.values.countryBStringValue ?? ""
            let match = each.values.matchIntValue ?? 0
            let category = each.values.categoryStringValue ?? "N/A"

            let hash = "\(city),\(venue),\(date),\(countryA),\(countryB),\(match),\(category)"
            var group = dictionary[hash] ?? []
            group.append(each)
            dictionary[hash] = group
        }
        return dictionary.values
    }

    //TODO pass lang into here
    private func getToken(name: String,
                          symbol: String,
                          forTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent,
                          index: UInt16,
                          inWallet account: Wallet,
                          server: RPCServer) -> TokenScript.Token {

        xmlHandler.getToken(
            name: name,
            symbol: symbol,
            fromTokenIdOrEvent: tokenIdOrEvent,
            index: index,
            inWallet: account,
            server: server,
            tokenType: token.type,
            assetDefinitionStore: assetDefinitionStore)
    }

    private func getFirstMatchingEvent(nonFungible: NonFungibleFromJson, inWallet account: Wallet, isSourcedFromEvents: Bool) -> EventInstanceValue? {
        if isSourcedFromEvents, let attributeWithEventSource = xmlHandler.attributesWithEventSource.first, let eventFilter = attributeWithEventSource.eventOrigin?.eventFilter, let eventName = attributeWithEventSource.eventOrigin?.eventName, let eventContract = attributeWithEventSource.eventOrigin?.contract {
            let filterName = eventFilter.name
            let filterValue: String
            if let implicitAttribute = EventSource.functional.convertToImplicitAttribute(string: eventFilter.value) {
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
            return eventsDataStore.getMatchingEvent(for: eventContract, tokenContract: token.contractAddress, server: token.server, eventName: eventName, filterName: filterName, filterValue: filterValue)
        } else {
            return nil
        }
    }

    private func getTokenIdOrEvent(event: EventInstanceValue?, nonFungible: NonFungibleFromJson) -> TokenIdOrEvent {
        let tokenId = BigUInt(nonFungible.tokenId) ?? BigUInt(0)
        let tokenIdOrEvent: TokenIdOrEvent
        if let eventNonOptional = event {
            tokenIdOrEvent = .event(tokenId: tokenId, event: eventNonOptional)
        } else {
            tokenIdOrEvent = .tokenId(tokenId: tokenId)
        }
        return tokenIdOrEvent
    }

    private func getTokenForNonFungible(nonFungible: NonFungibleFromJson, inWallet account: Wallet, server: RPCServer, isSourcedFromEvents: Bool, tokenType: TokenType) -> TokenScript.Token? {
        switch nonFungible.tokenType {
        case .erc721:
            break
        case .erc1155:
            guard !nonFungible.value.isZero else { return nil }
        }

        let event = getFirstMatchingEvent(nonFungible: nonFungible, inWallet: account, isSourcedFromEvents: isSourcedFromEvents)
        let tokenIdOrEvent: TokenIdOrEvent = getTokenIdOrEvent(event: event, nonFungible: nonFungible)

        var values = xmlHandler.resolveAttributesBypassingCache(
            withTokenIdOrEvent: tokenIdOrEvent,
            server: token.server,
            account: account,
            assetDefinitionStore: assetDefinitionStore)

        values.setTokenId(string: nonFungible.tokenId)
        if let date = nonFungible.collectionCreatedDate {
            //Storing as GeneralisedTime because we only support that for date/time formats in TokenScript. We are using the same `values` infrastructure
            var generalisedTime = GeneralisedTime()
            generalisedTime.timeZone = TimeZone.current
            generalisedTime.date = date
            values.setCollectionCreatedDate(generalisedTime: generalisedTime)
        }
        values.collectionDescriptionStringValue = nonFungible.collectionDescription
        values.setName(string: nonFungible.name)
        values.setDescription(string: nonFungible.description)
        values.setImageUrl(string: nonFungible.imageUrl)
        values.setContractImageUrl(string: nonFungible.contractImageUrl)
        values.setThumbnailUrl(string: nonFungible.thumbnailUrl)
        values.setExternalLink(string: nonFungible.externalLink)
        values.backgroundColorStringValue = nonFungible.backgroundColor
        values.setTraits(value: nonFungible.traits)
        values.setValue(int: nonFungible.value)
        values.setDecimals(int: nonFungible.decimals)
        values.setTokenType(string: nonFungible.tokenType.rawValue)

        values.setMeltStringValue(string: nonFungible.meltStringValue)
        values.setMeltFeeRatio(int: nonFungible.meltFeeRatio)
        values.setMeltFeeMaxRatio(int: nonFungible.meltFeeMaxRatio)
        values.setTotalSupplyStringValue(string: nonFungible.totalSupplyStringValue)
        values.setCirculatingSupply(string: nonFungible.circulatingSupplyStringValue)
        values.setReserveStringValue(string: nonFungible.reserveStringValue)
        values.setNonFungible(bool: nonFungible.nonFungible)
        values.setBlockHeight(int: nonFungible.blockHeight)
        values.setMintableSupply(bigInt: nonFungible.mintableSupply)
        values.setTransferable(string: nonFungible.transferable)
        values.setSupplyModel(string: nonFungible.supplyModel)
        values.setIssuer(string: nonFungible.issuer)
        values.setCreated(string: nonFungible.created)
        values.setTransferFee(string: nonFungible.transferFee)

        values.setCollection(collection: nonFungible.collection)
        values.setSlug(string: nonFungible.slug)
        values.setCreator(creator: nonFungible.creator)

        let status: TokenScript.Token.Status
        let cryptoKittyGenerationWhenDataNotAvailable = "-1"
        if let generation = nonFungible.generationTrait, generation.value == cryptoKittyGenerationWhenDataNotAvailable {
            status = .availableButDataUnavailable
        } else {
            status = .available
        }
        return TokenScript.Token(
                tokenIdOrEvent: tokenIdOrEvent,
                tokenType: nonFungible.tokenType.asTokenType,
                index: 0,
                name: nonFungible.contractName,
                symbol: "",
                status: status,
                values: values)
    }

    private func getTokenHolder(for tokens: [TokenScript.Token]) -> TokenHolder {
        return TokenHolder(
                tokens: tokens,
                contractAddress: token.contractAddress,
                hasAssetDefinition: xmlHandler.hasAssetDefinition)
    }

}

extension TokenScript.Token {
    //TODO Convenience-only. (Look for references). Should remove once we generalize things further and not hardcode the use of seatId
    var seatId: Int {
        return values.numeroIntValue.flatMap { Int($0) } ?? 0
    }
}
