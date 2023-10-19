//
//  TokenAdaptor.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Combine
import Foundation
import AlphaWalletOpenSea
import AlphaWalletTokenScript
import BigInt

extension TokenHolder: ObservableObject { }

private var subjectCancellableKey: Void?
extension TokenHolder {

    fileprivate var cancellable: Cancellable? {
      get { objc_getAssociatedObject(self, &subjectCancellableKey) as? Cancellable }
      set { objc_setAssociatedObject(self, &subjectCancellableKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

public struct TokenAdaptor {
    let nftProvider: NFTProvider
    let assetDefinitionStore: AssetDefinitionStore
    let eventsDataStore: NonActivityEventsDataStore
    let wallet: Wallet

    public init(assetDefinitionStore: AssetDefinitionStore,
                eventsDataStore: NonActivityEventsDataStore,
                wallet: Wallet,
                nftProvider: NFTProvider) {

        self.nftProvider = nftProvider
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
    }

    public func xmlHandler(token: TokenScriptSupportable) -> XMLHandler {
        assetDefinitionStore.xmlHandler(forTokenScriptSupportable: token)
    }

    public func xmlHandler(contract: AlphaWallet.Address, tokenType: TokenType) -> XMLHandler {
        return assetDefinitionStore.xmlHandler(forContract: contract, tokenType: tokenType)
    }

    public func tokenScriptOverrides(token: TokenScriptSupportable) -> TokenScriptOverrides {
        return TokenScriptOverrides(token: token, tokenAdaptor: self)
    }

    //`sourceFromEvents`: We'll usually source from events if available, except when we are actually using this func to create the filter to fetch the events
    public func getTokenHolders(token: TokenScriptSupportable, isSourcedFromEvents: Bool = true) async -> [TokenHolder] {
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc875, .erc721ForTickets:
            return getNotSupportedByNonFungibleJsonTokenHolders(token: token)
        case .erc721, .erc1155:
            let tokenType = NonFungibleFromJsonSupportedTokenHandling(token: token)
            switch tokenType {
            case .supported:
                return await getSupportedByNonFungibleJsonTokenHolders(token: token, isSourcedFromEvents: isSourcedFromEvents)
            case .notSupported:
                return getNotSupportedByNonFungibleJsonTokenHolders(token: token)
            }
        }
    }

    public func getTokenHolder(token: TokenScriptSupportable) -> TokenHolder {
        //TODO id 1 for fungibles. Might come back to bite us?
        let hardcodedTokenIdForFungibles = BigUInt(1)
        let xmlHandler = assetDefinitionStore.xmlHandler(forContract: token.contractAddress, tokenType: token.type)
            //TODO Event support, if/when designed for fungibles
        let values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), server: token.server, account: wallet.address)
        let tokenScriptToken = TokenScript.Token(
            tokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles),
            tokenType: token.type,
            index: 0,
            name: token.name,
            symbol: token.symbol,
            status: .available,
            values: values)

        let tokenHolder = TokenHolder(tokens: [tokenScriptToken], contractAddress: token.contractAddress, hasAssetDefinition: true)

        //NOTE: resolve all attibutest at once and notify token holder
        let assetAttributeValues = AssetAttributeValues(attributeValues: values)
        tokenHolder.cancellable = assetAttributeValues.resolveAllAttributes()
            .sink { [weak tokenHolder] _ in
                tokenHolder?.objectWillChange.send()
                tokenHolder?.cancellable = nil
            }

        return tokenHolder
    }

    //TODO: is it possible to make single token holder with multiple token ids without making each token holder for each token id?
    private func getNotSupportedByNonFungibleJsonTokenHolders(token: TokenScriptSupportable) -> [TokenHolder] {
        var tokens = [TokenScript.Token]()
        switch token.type {
        case .erc875, .erc721ForTickets, .erc721, .erc1155, .nativeCryptocurrency:
            for (index, item) in token.balanceNft.enumerated() {
                //id is the value of the bytes32 token
                let id = item.balance
                guard isNonZeroBalance(id, tokenType: token.type) else { continue }
                if let tokenInt = BigUInt(id.drop0x, radix: 16) {
                    //TODO Event support, if/when designed, for non-OpenSea. Probably need `distinct` or something to that effect
                    let token = getToken(name: token.name, symbol: token.symbol, forTokenIdOrEvent: .tokenId(tokenId: tokenInt), index: UInt16(index), token: token)
                    tokens.append(token)
                }
            }
            return bundle(tokens: tokens, token: token)
        case .erc20:
            //For fungibles, we have to get 1 token even if the balance.count is 0. Maybe we check value? No, even if value is 0, there might be attributes
            let tokenInt: BigUInt = .init(1)
            let index = 0

            //TODO Event support, if/when designed, for non-OpenSea. Probably need `distinct` or something to that effect
            let tokenScriptToken = getToken(name: token.name, symbol: token.symbol, forTokenIdOrEvent: .tokenId(tokenId: tokenInt), index: UInt16(index), token: token)
            tokens.append(tokenScriptToken)
            return bundle(tokens: tokens, token: token)
        }
    }

    private func getSupportedByNonFungibleJsonTokenHolders(token: TokenScriptSupportable, isSourcedFromEvents: Bool) async -> [TokenHolder] {
        var tokens = [TokenScript.Token]()
        for nonFungibleBalance in token.balanceNft.compactMap({ $0.nonFungibleBalance }) {
            if let token = await getTokenForNonFungible(nonFungible: nonFungibleBalance, token: token, isSourcedFromEvents: isSourcedFromEvents) {
                tokens.append(token)
            }
        }
        return bundle(tokens: tokens, token: token)
    }

    //NOTE: internal for testing purposes
    public func bundleTestsOnly(tokens: [TokenScript.Token], token: TokenScriptSupportable) -> [TokenHolder] {
        bundle(tokens: tokens, token: token)
    }

    private func bundle(tokens: [TokenScript.Token], token: TokenScriptSupportable) -> [TokenHolder] {
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc875:
            if !tokens.isEmpty && tokens[0].isSpawnableMeetupContract {
                return tokens.sorted { $0.id < $1.id }.map { getTokenHolder(for: [$0], token: token) }
            } else {
                var tokenHolders: [TokenHolder] = []
                for each in groupTokensByFields(tokens: tokens) {
                    for tokens in breakBundlesFurtherToHaveContinuousSeatRange(tokens: each) {
                        tokenHolders.append(getTokenHolder(for: tokens, token: token))
                    }
                }
                return sortBundlesUpcomingFirst(bundles: tokenHolders)
            }
        case .erc721, .erc721ForTickets, .erc1155:
            return tokens.map { getTokenHolder(for: [$0], token: token) }
        }
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
            var group = dictionary[hash, default: []]
            group.append(each)
            dictionary[hash] = group
        }
        return dictionary.values
    }

    //TODO pass lang into here
    private func getToken(name: String, symbol: String, forTokenIdOrEvent tokenIdOrEvent: TokenIdOrEvent, index: UInt16, token: TokenScriptSupportable) -> TokenScript.Token {
        let xmlHandler = xmlHandler(token: token)
        return xmlHandler.getToken(name: name, symbol: symbol, fromTokenIdOrEvent: tokenIdOrEvent, index: index, inWallet: wallet.address, server: token.server, tokenType: token.type)
    }

    private func getFirstMatchingEvent(nonFungible: NonFungibleFromJson, token: TokenScriptSupportable, isSourcedFromEvents: Bool) async -> EventInstanceValue? {
        let xmlHandler = xmlHandler(token: token)
        if isSourcedFromEvents, let attributeWithEventSource = xmlHandler.attributesWithEventSource.first, let eventFilter = attributeWithEventSource.eventOrigin?.eventFilter, let eventName = attributeWithEventSource.eventOrigin?.eventName, let eventContract = attributeWithEventSource.eventOrigin?.contract {
            let filterName = eventFilter.name
            let filterValue: String
            if let implicitAttribute = EventSource.convertToImplicitAttribute(string: eventFilter.value) {
                switch implicitAttribute {
                case .tokenId:
                    filterValue = eventFilter.value.replacingOccurrences(of: "${tokenId}", with: nonFungible.tokenId)
                case .ownerAddress:
                    filterValue = eventFilter.value.replacingOccurrences(of: "${ownerAddress}", with: wallet.address.eip55String)
                case .label, .contractAddress, .symbol:
                    filterValue = eventFilter.value
                }
            } else {
                filterValue = eventFilter.value
            }
            return await eventsDataStore.getMatchingEvent(for: eventContract, tokenContract: token.contractAddress, server: token.server, eventName: eventName, filterName: filterName, filterValue: filterValue)
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

    private func getTokenForNonFungible(nonFungible: NonFungibleFromJson, token: TokenScriptSupportable, isSourcedFromEvents: Bool) async -> TokenScript.Token? {
        switch nonFungible.tokenType {
        case .erc721:
            break
        case .erc1155:
            guard !nonFungible.value.isZero else { return nil }
        }

        let event = await getFirstMatchingEvent(nonFungible: nonFungible, token: token, isSourcedFromEvents: isSourcedFromEvents)
        let tokenIdOrEvent: TokenIdOrEvent = getTokenIdOrEvent(event: event, nonFungible: nonFungible)
        let xmlHandler = xmlHandler(token: token)
        var values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: tokenIdOrEvent, server: token.server, account: wallet.address)
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
        values.setAnimationUrl(string: nonFungible.animationUrl)
        values.setContractImageUrl(string: nonFungible.contractImageUrl)
        values.setThumbnailUrl(string: nonFungible.thumbnailUrl)
        values.setExternalLink(string: nonFungible.externalLink)
        values.backgroundColorStringValue = nonFungible.backgroundColor
        values.setTraits(value: nonFungible.traits)
        values.setValue(int: nonFungible.value)
        values.setTokenType(string: nonFungible.tokenType.rawValue)

        if let token = await nftProvider.enjinToken(tokenId: tokenIdOrEvent.tokenId) {
            values.setMeltStringValue(string: token.meltValue)
            values.setMeltFeeRatio(int: token.meltFeeRatio)
            values.setMeltFeeMaxRatio(int: token.meltFeeMaxRatio)
            values.setTotalSupplyStringValue(string: token.totalSupply)
            values.setCirculatingSupply(string: token.circulatingSupply)
            values.setReserveStringValue(string: token.reserve)
            values.setNonFungible(bool: token.nonFungible)
            values.setBlockHeight(int: token.blockHeight)
            values.setMintableSupply(bigInt: BigInt(token.mintableSupply))
            values.setTransferable(string: token.transferable)
            values.setSupplyModel(string: token.supplyModel)
            values.setCreated(string: token.createdAt)
            values.setTransferFee(string: token.transferFee)
        }

        values.setCollection(collection: nonFungible.collection)
        values.setCollectionId(string: nonFungible.collectionId)
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

    private func getTokenHolder(for tokens: [TokenScript.Token], token: TokenScriptSupportable) -> TokenHolder {
        let xmlHandler = xmlHandler(token: token)
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
