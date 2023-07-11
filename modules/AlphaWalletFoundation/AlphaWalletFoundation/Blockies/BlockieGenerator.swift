//
//  BlockieGenerator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.11.2020.
//

import Foundation
import BlockiesSwift
import UIKit.UIImage
import Combine
import AlphaWalletENS
import AlphaWalletCore

public protocol NftAssetImageProvider: AnyObject {
    func assetImageUrl(for url: Eip155URL) -> AnyPublisher<URL, PromiseError>
}

public class BlockiesGenerator {
    private enum BlockieSize {
        case sized(size: Int, scale: Int)
        case none
    }

    private let queue = DispatchQueue(label: "org.alphawallet.swift.blockies.generator")

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

    public func getBlockieOrEnsAvatarImage(address: AlphaWallet.Address, ens: String? = nil, size: Int = 8, scale: Int = 3, fallbackImage: BlockiesImage) -> AnyPublisher<BlockiesImage, Never> {
        return getBlockieOrEnsAvatarImage(address: address, ens: ens, size: size, scale: size)
            .prepend(fallbackImage)
            .replaceError(with: fallbackImage)
            .eraseToAnyPublisher()
    }

    public func getBlockieOrEnsAvatarImage(address: AlphaWallet.Address, ens: String? = nil, size: Int = 8, scale: Int = 3) -> AnyPublisher<BlockiesImage, SmartContractError> {
        if let cached = self.cachedBlockie(address: address, size: .sized(size: size, scale: scale)) {
            return .just(cached)
        }

        func generageBlockieFallback() -> AnyPublisher<BlockiesImage, SmartContractError> {
            return createBlockieImage(address: address, size: size, scale: scale)
                .receive(on: queue) //NOTE: to make sure that updating storage is thread safe
                .handleEvents(receiveOutput: { blockie in
                    self.cacheBlockie(address: address, blockie: blockie, size: .sized(size: size, scale: scale))
                }).mapError { SmartContractError.embedded($0) }
                .eraseToAnyPublisher()
        }

        return Just(address)
            .setFailureType(to: SmartContractError.self)
            .receive(on: queue)
            .flatMap { [queue] address -> AnyPublisher<BlockiesImage, SmartContractError> in
                return self.fetchEnsAvatar(for: address, ens: ens)
                    .receive(on: queue)
                    .handleEvents(receiveOutput: { blockie in
                        self.cacheBlockie(address: address, blockie: blockie, size: .none)
                    }).catch { _ in return generageBlockieFallback() }
                    .eraseToAnyPublisher()
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private func fetchEnsAvatar(for address: AlphaWallet.Address, ens: String?) -> AnyPublisher<BlockiesImage, SmartContractError> {
        return ensTextRecordFetcher.getEnsAvatar(for: address, ens: ens)
            .flatMap { imageOrEip155 -> AnyPublisher<BlockiesImage, SmartContractError> in
                switch imageOrEip155 {
                case .image(let img, _):
                    return .just(img)
                case .eip155(let url, let raw):
                    return self.getImageFromOpenSea(for: url, rawUrl: raw, nameOrAddress: ens ?? address.eip55String)
                }
            }.eraseToAnyPublisher()
    }

    private func getImageFromOpenSea(for url: Eip155URL, rawUrl: String, nameOrAddress: String) -> AnyPublisher<BlockiesImage, SmartContractError> {
        return assetImageProvider.assetImageUrl(for: url)
            .mapError { SmartContractError.embedded($0) }
            //NOTE: cache fetched open sea image url and rewrite ens avatar with new image
            .handleEvents(receiveOutput: { [storage] url in
                let key = DomainNameLookupKey(nameOrAddress: nameOrAddress, server: .forResolvingDomainNames, record: .avatar)
                storage.addOrUpdate(record: .init(key: key, value: .record(url.absoluteString)))
            }).map { url -> BlockiesImage in
                return .url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true)
            }.catch { error -> AnyPublisher<BlockiesImage, SmartContractError> in
                guard let url = URL(string: rawUrl) else { return .fail(.embedded(error)) }

                return .just(.url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true))
            }.share()
            .eraseToAnyPublisher()
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

    private func createBlockieImage(address: AlphaWallet.Address, size: Int, scale: Int) -> AnyPublisher<BlockiesImage, PromiseError> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        return Deferred {
            Future<BlockiesImage, PromiseError> { seal in
                DispatchQueue.global().async {
                    let blockies = Blockies(seed: address.eip55String, size: size, scale: scale)
                    DispatchQueue.main.async {
                        if let image = blockies.createImage() {
                            seal(.success(.image(image: image, isEnsAvatar: false)))
                        } else {
                            seal(.failure(.some(error: AnyError.blockieCreateFailure)))
                        }
                    }
                }
            }
        }.eraseToAnyPublisher()
    }
}
