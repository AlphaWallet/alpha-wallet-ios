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
    var token: TokenObject
    init(token: TokenObject) {
        self.token = token
    }

    public func getTokenHolders() -> [TokenHolder] {
        switch token.type {
        case .ether, .erc20, .erc875:
            return getNonCryptoKittyTokenHolders()
        case .erc721:
            let tokenType = CryptoKittyHandling(address: token.address)
            switch tokenType {
            case .cryptoKitty:
                return getCryptoKittyTokenHolders()
            case .otherNonFungibleToken:
                return getNonCryptoKittyTokenHolders()
            }
        }
    }

    private func getNonCryptoKittyTokenHolders() -> [TokenHolder] {
        let balance = token.balance
        var tokens = [Token]()
        for (index, item) in balance.enumerated() {
            //id is the value of the bytes32 token
            let id = item.balance
            guard isNonZeroBalance(id) else { continue }
            if let tokenInt = BigUInt(id.drop0x, radix: 16) {
                let token = getToken(name: self.token.name, for: tokenInt, index: UInt16(index))
                tokens.append(token)
            }
        }

        return bundle(tokens: tokens)
    }

    private func getCryptoKittyTokenHolders() -> [TokenHolder] {
        let balance = token.balance
        var tokens = [Token]()
        for (_, item) in balance.enumerated() {
            let jsonString = item.balance
            if let token = getTokenForCryptoKitty(forJSONString: jsonString) {
                tokens.append(token)
            }
        }

        return bundle(tokens: tokens)
    }

    func bundle(tokens: [Token]) -> [TokenHolder] {
        switch token.type {
        case .ether, .erc20, .erc875:
            break
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
            let d0 = $0.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            let d1 = $1.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            return d0 < d1
        }
    }

    //If sequential or have the same seat number, add them together
    ///e.g 21, 22, 25 is broken up into 2 bundles: 21-22 and 25.
    ///e.g 21, 21, 22, 25 is broken up into 2 bundles: (21,21-22) and 25.
    private func breakBundlesFurtherToHaveContinuousSeatRange(tokens: [Token]) -> [[Token]] {
        let tokens = tokens.sorted {
            let s0 = $0.values["numero"] as? Int ?? 0
            let s1 = $1.values["numero"] as? Int ?? 0
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
            let city = each.values["locality"] as? String ?? "N/A"
            let venue = each.values["venue"] as? String ?? "N/A"
            let date = each.values["time"] as? GeneralisedTime ?? GeneralisedTime()
            let countryA = each.values["countryA"] as? String ?? ""
            let countryB = each.values["countryB"] as? String ?? ""
            let match = each.values["match"] as? Int ?? 0
            let category = each.values["category"] as? String ?? "N/A"

            let hash = "\(city),\(venue),\(date),\(countryA),\(countryB),\(match),\(category)"
            var group = dictionary[hash] ?? []
            group.append(each)
            dictionary[hash] = group
        }
        return dictionary.values
    }

    //TODO pass lang into here
    private func getToken(name: String, for id: BigUInt, index: UInt16) -> Token {
        return XMLHandler(contract: token.contract).getToken(name: name, fromTokenId: id, index: index)
    }

    private func getTokenForCryptoKitty(forJSONString jsonString: String) -> Token? {
        guard let data = jsonString.data(using: .utf8), let cat = try? JSONDecoder().decode(CryptoKitty.self, from: data) else { return nil }
        var values = [String: AssetAttributeValue]()
        values["tokenId"] = cat.tokenId
        values["description"] = cat.description
        values["imageUrl"] = cat.imageUrl
        values["thumbnailUrl"] = cat.thumbnailUrl
        values["externalLink"] = cat.externalLink
        values["traits"] = cat.traits

        let status: Token.Status
        let cryptoKittyGenerationWhenDataNotAvailable = "-1"
        if let generation = cat.generationTrait, generation.value == cryptoKittyGenerationWhenDataNotAvailable {
            status = .availableButDataUnavailable
        } else {
            status = .available
        }
        return Token(
                id: BigUInt(cat.tokenId)!,
                index: 0,
                name: "name",
                status: status,
                values: values
        )
    }

    private func getTokenHolder(for tokens: [Token]) -> TokenHolder {
        return TokenHolder(
                tokens: tokens,
                contractAddress: token.contract,
                hasAssetDefinition: XMLHandler(contract: token.contract).hasAssetDefinition
        )
    }

}

extension Token {
    //TODO Convenience-only. (Look for references). Should remove once we generalize things further and not hardcode the use of seatId
    var seatId: Int {
        return values["numero"] as? Int ?? 0
    }
}
