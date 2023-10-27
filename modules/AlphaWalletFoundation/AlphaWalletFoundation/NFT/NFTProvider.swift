//
//  NFTService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.03.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletOpenSea
import BigInt

public typealias NonFungiblesTokens = (openSea: OpenSeaAddressesToNonFungibles, enjin: Void)

public protocol NFTProvider {
    func collectionStats(collectionId: String) -> AnyPublisher<Stats, PromiseError>
    func nonFungible() -> AnyPublisher<NonFungiblesTokens, Never>
    func enjinToken(tokenId: TokenId) async -> EnjinToken?
}

extension OpenSea: NftAssetImageProvider {
    public func assetImageUrl(contract: AlphaWallet.Address, id: BigUInt) async throws -> URL {
        //TODO skip fetch if we already have it
        let asset = try await fetchAsset(contract: contract, id: id)
        let imageUrls = [asset.imageUrl, asset.thumbnailUrl, asset.imageOriginalUrl].compactMap { URL(string: $0) }
        if let url = imageUrls.first {
            return url
        } else {
            struct AssetImageUrlNotFound: Error {}
            throw PromiseError(error: AssetImageUrlNotFound())
        }
    }
}

extension Constants.Credentials {
    static var enjinCredentials: EnjinCredentials? {
        guard let email = Constants.Credentials.enjinUserName, let password = Constants.Credentials.enjinUserPassword else { return nil }
        return (email: email, password: password)
    }
}

public final class AlphaWalletNFTProvider: NFTProvider {
    private let openSea: OpenSea
    private let enjin: Enjin
    private let wallet: Wallet
    private let server: RPCServer

    public init(analytics: AnalyticsLogger,
                wallet: Wallet,
                server: RPCServer,
                config: Config,
                storage: RealmStore) {

        self.wallet = wallet
        self.server = server
        enjin = Enjin(
            server: server,
            storage: storage,
            accessTokenStore: config,
            credentials: Constants.Credentials.enjinCredentials)

        openSea = OpenSea(
            analytics: analytics,
            server: server,
            config: config)
    }

    public func collectionStats(collectionId: String) -> AnyPublisher<Stats, PromiseError> {
        openSea.collectionStats(collectionId: collectionId)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func enjinToken(tokenId: TokenId) async -> EnjinToken? {
        await enjin.token(tokenId: tokenId)
    }

    public func nonFungible() -> AnyPublisher<NonFungiblesTokens, Never> {
        let key = AddressAndRPCServer(address: wallet.address, server: server)

        let tokensFromOpenSeaPromise = openSea.nonFungible(wallet: wallet)
            .replaceError(with: [:])

        let enjinTokensPromise = enjin.fetchTokens(wallet: wallet)
            .receive(on: DispatchQueue.global())
            .mapToVoid()
            .replaceError(with: ())

        return Publishers.CombineLatest(tokensFromOpenSeaPromise, enjinTokensPromise)
            .map { ($0, $1) }
            .eraseToAnyPublisher()
    }

}

extension Config: EnjinAccessTokenStore {
    fileprivate static func accessTokenKey(email: String) -> String {
        return "AccessTokenKey-\(email)"
    }

    public func accessToken(email: String) -> EnjinAccessToken? {
        let key = Self.accessTokenKey(email: email)
        return defaults.value(forKey: key) as? EnjinAccessToken
    }

    public func set(accessToken: EnjinAccessToken?, email: String) {
        let key = Self.accessTokenKey(email: email)
        guard let value = accessToken else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(value, forKey: key)
    }
}
