//
//  BalanceHelper.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/25/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import RealmSwift
import BigInt

class TokenAdaptor {
    private let token: TokenObject
    private let assetDefinitionStore: AssetDefinitionStore

    init(token: TokenObject, assetDefinitionStore: AssetDefinitionStore) {
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
    }

    public func getTokenHolders(forWallet account: Wallet) -> [TokenHolder] {
        switch token.type {
        case .nativeCryptocurrency, .erc20, .erc875:
            return getNotSupportedByOpenSeaTokenHolders(forWallet: account)
        case .erc721:
            let tokenType = OpenSeaSupportedNonFungibleTokenHandling(token: token)
            switch tokenType {
            case .supportedByOpenSea:
                return getSupportedByOpenSeaTokenHolders()
            case .notSupportedByOpenSea:
                return getNotSupportedByOpenSeaTokenHolders(forWallet: account)
            }
        }
    }

    private func getNotSupportedByOpenSeaTokenHolders(forWallet account: Wallet) -> [TokenHolder] {
        let balance = token.balance
        var tokens = [Token]()
        for (index, item) in balance.enumerated() {
            //id is the value of the bytes32 token
            let id = item.balance
            guard isNonZeroBalance(id) else { continue }
            if let tokenInt = BigUInt(id.drop0x, radix: 16) {
                let server = self.token.server
                let token = getToken(name: self.token.name, symbol: self.token.symbol, for: tokenInt, index: UInt16(index), inWallet: account, server: server)
                tokens.append(token)
            }
        }

        return bundle(tokens: tokens)
    }

    private func getSupportedByOpenSeaTokenHolders() -> [TokenHolder] {
        let balance = token.balance
        var tokens = [Token]()
        for item in balance {
            let jsonString = item.balance
            if let token = getTokenForOpenSeaNonFungible(forJSONString: jsonString) {
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
        case .erc721:
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
    private func getToken(name: String, symbol: String, for id: BigUInt, index: UInt16, inWallet account: Wallet, server: RPCServer) -> Token {
        return XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).getToken(name: name, symbol: symbol, fromTokenId: id, index: index, inWallet: account, server: server)
    }

    private func getTokenForOpenSeaNonFungible(forJSONString jsonString: String) -> Token? {
        guard let data = jsonString.data(using: .utf8), let nonFungible = try? JSONDecoder().decode(OpenSeaNonFungible.self, from: data) else { return nil }
        var values = [AttributeId: AssetAttributeSyntaxValue ]()
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
                id: BigUInt(nonFungible.tokenId)!,
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
                hasAssetDefinition: XMLHandler(contract: token.contractAddress, assetDefinitionStore: assetDefinitionStore).hasAssetDefinition
        )
    }

}

extension Token {
    //TODO Convenience-only. (Look for references). Should remove once we generalize things further and not hardcode the use of seatId
    var seatId: Int {
        return values["numero"]?.intValue.flatMap { Int($0)}  ?? 0
    }
}
