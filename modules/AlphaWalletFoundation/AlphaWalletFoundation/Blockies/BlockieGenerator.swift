//
//  BlockieGenerator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.11.2020.
//

import Foundation
import UIKit.UIImage
import Combine
import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletENS
import BigInt
import BlockiesSwift

public protocol NftAssetImageProvider: AnyObject {
    func assetImageUrl(contract: AlphaWallet.Address, id: BigUInt) async throws -> URL
}

//TODO improve actor/nonisolated?
public actor BlockiesGenerator {
    private enum BlockieSize {
        case sized(size: Int, scale: Int)
        case none
    }

    private var cachedBlockieForPerformanceDevelopment: BlockiesImage?

    /// Address related icons cache with image size and scale
    private var cache: [String: BlockiesImage] = [:]
    /// Address related icons cache without image size. Cache is using for determine images without sizes and scales, fetched out from OpenSea
    private var sizelessCache: [String: BlockiesImage] = [:]
    private let storage: DomainNameRecordsStorage
    private lazy var ensTextRecordFetcher = GetEnsTextRecord(blockchainProvider: blockchainProvider, storage: storage)
    private let assetImageProvider: NftAssetImageProvider
    private let blockchainProvider: BlockchainProvider

    public init(assetImageProvider: NftAssetImageProvider,
                storage: DomainNameRecordsStorage,
                blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
        self.assetImageProvider = assetImageProvider
        self.storage = storage
    }

    public func getBlockieOrEnsAvatarImage(address: AlphaWallet.Address, ens: String? = nil, size: Int = 8, scale: Int = 3, fallbackImage: BlockiesImage) async -> BlockiesImage {
        do {
            return try await getBlockieOrEnsAvatarImage(address: address, ens: ens, size: size, scale: size)
        } catch {
            return fallbackImage
        }
    }

    private func getCachedBlockieForPerformanceDevelopment(setDefault block: @autoclosure () -> BlockiesImage) -> BlockiesImage {
        if cachedBlockieForPerformanceDevelopment == nil {
            cachedBlockieForPerformanceDevelopment = block()
        }
        return cachedBlockieForPerformanceDevelopment!
    }

    //TODO speed up. Callers block if we want for generation at launch, without a default?
    public func getBlockieOrEnsAvatarImage(address: AlphaWallet.Address, ens: String? = nil, size: Int = 8, scale: Int = 3) async throws -> BlockiesImage {
        if let cached = self.cachedBlockie(address: address, size: .sized(size: size, scale: scale)) {
            return cached
        }

        func generateBlockieFallback() async throws -> BlockiesImage {
            let blockie = try await createBlockieImage(address: address, size: size, scale: scale)
            await cacheBlockie(address: address, blockie: blockie, size: .sized(size: size, scale: scale))
            return blockie
        }

        //Development only, so performance is less important
        if Config().development.shouldDisableBlockieGeneration {
            return getCachedBlockieForPerformanceDevelopment(setDefault: BlockiesImage.image(image: UIImage(), isEnsAvatar: false))
        }

        do {
            let blockie = try await fetchEnsAvatar(for: address, ens: ens)
            cacheBlockie(address: address, blockie: blockie, size: .none)
            return blockie
        } catch {
            //TODO not cache this fallback too? Performance?
            return try await generateBlockieFallback()
        }
    }

    private func fetchEnsAvatar(for address: AlphaWallet.Address, ens: String?) async throws -> BlockiesImage {
        let imageOrEip155 = try await ensTextRecordFetcher.getEnsAvatar(for: address, ens: ens)
        switch imageOrEip155 {
        case .image(let img, _):
            return img
        case .eip155(let url, let raw):
            return try await getImageFromOpenSea(contract: url.contract, id: url.id, rawUrl: raw, nameOrAddress: ens ?? address.eip55String)
        }
    }

    private func getImageFromOpenSea(contract: AlphaWallet.Address, id: BigUInt, rawUrl: String, nameOrAddress: String) async throws -> BlockiesImage {
        do {
            let url = try await assetImageProvider.assetImageUrl(contract: contract, id: id)
            //NOTE: cache fetched open sea image url and rewrite ens avatar with new image
            let key = DomainNameLookupKey(nameOrAddress: nameOrAddress, server: .forResolvingDomainNames, record: .avatar)
            await storage.addOrUpdate(record: .init(key: key, value: .record(url.absoluteString)))
            let blockies = BlockiesImage.url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true)
            return blockies
        } catch {
            guard let url = URL(string: rawUrl) else { throw SmartContractError.embedded(error) }
            return BlockiesImage.url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true)
        }
    }

    private func cacheBlockie(address: AlphaWallet.Address, blockie: BlockiesImage, size: BlockieSize) {
        switch size {
        case .sized(let size, let scale):
            let key = "\(address.eip55String)-\(size)-\(scale)"
            cache[key] = blockie
        case .none:
            sizelessCache[address.eip55String] = blockie
        }
    }

    private func cachedBlockie(address: AlphaWallet.Address, size: BlockieSize) -> BlockiesImage? {
        switch size {
        case .sized(let size, let scale):
            let key = "\(address.eip55String)-\(size)-\(scale)"
            return cache[key] ?? sizelessCache[address.eip55String]
        case .none:
            return sizelessCache[address.eip55String]
        }
    }

    private func createBlockieImage(address: AlphaWallet.Address, size: Int, scale: Int) async throws -> BlockiesImage {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        let blockies = Blockies(seed: address.eip55String, size: size, scale: scale)
        if let image = blockies.createImage() {
            return .image(image: image, isEnsAvatar: false)
        } else {
            throw AnyError.blockieCreateFailure
        }
    }
}
