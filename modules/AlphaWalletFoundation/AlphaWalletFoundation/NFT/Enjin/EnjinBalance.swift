//
//  EnjinBalance.swift
//  AlphaWalletFoundation-AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.02.2023.
//

import Foundation
import BigInt

public struct EnjinError: Error {
    let localizedDescription: String
}

struct EnjinBalancesResponse {
    let balances: [EnjinBalance]
}

struct EnjinBalance {
    let value: Int
    let tokenId: String

    init?(balance: GetEnjinBalancesQuery.Data.EnjinBalance) {
        guard let id = balance.token?.id else { return nil }

        tokenId = id
        value = balance.value ?? 0
    }
}

struct EnjinTokensResponse {
    let owner: AlphaWallet.Address
    let tokens: [EnjinToken]
}

public struct EnjinToken {
    let tokenId: String
    let name: String
    let creator: String
    let meltValue: String
    let meltFeeRatio: Int
    let meltFeeMaxRatio: Int
    let supplyModel: String
    let totalSupply: String
    let circulatingSupply: String
    let reserve: String
    let transferable: String
    let nonFungible: Bool
    let blockHeight: Int
    let mintableSupply: Double
    let createdAt: String
    let transferFee: String
    let value: Int
}

extension EnjinToken {
    
    init(object: EnjinTokenObject) {
        tokenId = object.tokenId
        name = object.name
        creator = object.creator
        meltValue = object.meltValue
        meltFeeRatio = object.meltFeeRatio
        meltFeeMaxRatio = object.meltFeeMaxRatio
        supplyModel = object.supplyModel
        totalSupply = object.totalSupply
        circulatingSupply = object.circulatingSupply
        reserve = object.reserve
        transferable = object.transferable
        nonFungible = object.nonFungible
        blockHeight = object.blockHeight
        mintableSupply = object.mintableSupply
        value = object.value
        createdAt = object.createdAt
        transferFee = object.transferFee
    }

    init?(token: GetEnjinTokenQuery.Data.EnjinToken, balance: EnjinBalance) {
        guard let id = token.id.flatMap({ TokenIdConverter.addTrailingZerosPadding(string: $0) }) else { return nil }
        // NOTE: store with trailing zeros `70000000000019a4000000000000000000000000000000000000000000000000` instead of `70000000000019a4`
        tokenId = id
        name = token.name ?? ""
        creator = token.creator ?? ""
        meltValue = token.meltValue ?? ""
        meltFeeRatio = token.meltFeeRatio ?? 0
        meltFeeMaxRatio = token.meltFeeMaxRatio ?? 0
        supplyModel = token.supplyModel?.rawValue ?? ""
        totalSupply = token.totalSupply ?? ""
        circulatingSupply = token.circulatingSupply ?? ""
        reserve = token.reserve ?? ""
        transferable = token.transferable?.rawValue ?? ""
        nonFungible = token.nonFungible ?? false
        blockHeight = token.blockHeight ?? 0
        mintableSupply = token.mintableSupply ?? 0
        createdAt = token.createdAt ?? ""
        transferFee = token.transferFeeSettings?.type?.rawValue ?? ""
        value = balance.value
    }
}
