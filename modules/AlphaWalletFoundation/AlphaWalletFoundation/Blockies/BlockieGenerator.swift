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

public class BlockiesGenerator {
    private enum BlockieSize {
        case sized(size: Int, scale: Int)
        case none
    }

    private struct BlockieKey: Hashable {
        let address: AlphaWallet.Address
        let size: Int
        let scale: Int

        func hash(into hasher: inout Hasher) {
            hasher.combine(address.eip55String)
            hasher.combine(size)
            hasher.combine(scale)
        }
    }

    private let queue = DispatchQueue(label: "org.alphawallet.swift.blockies.generator")

    /// Address related icons cache with image size and scale
    private var cache: [BlockieKey: BlockiesImage] = [:]
    /// Address related icons cache without image size. Cache is using for determine images without sizes and scales, fetched out from OpenSea
    private var sizeLessCache: [AlphaWallet.Address: BlockiesImage] = [:]
    private let storage: EnsRecordsStorage
    private lazy var ensTextRecordFetcher = GetEnsTextRecord(server: .forResolvingEns, storage: storage)
    private let openSea: OpenSea

    public init(openSea: OpenSea, storage: EnsRecordsStorage) {
        self.openSea = openSea
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
                }).mapError { SmartContractError.embeded($0) }
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
        return openSea.fetchAssetImageUrl(for: url, server: .main).publisher
            .mapError { SmartContractError.embeded($0) }
            //NOTE: cache fetched open sea image url and rewrite ens avatar with new image
            .handleEvents(receiveOutput: { [storage] url in
                let key = EnsLookupKey(nameOrAddress: nameOrAddress, server: .forResolvingEns, record: .avatar)
                storage.addOrUpdate(record: .init(key: key, value: .record(url.absoluteString)))
            }).map { url -> BlockiesImage in
                return .url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true)
            }.catch { error -> AnyPublisher<BlockiesImage, SmartContractError> in
                guard let url = URL(string: rawUrl) else { return .fail(.embeded(error)) }

                return .just(.url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true))
            }.share()
            .eraseToAnyPublisher()
    }

    private func cacheBlockie(address: AlphaWallet.Address, blockie: BlockiesImage, size: BlockieSize) {
        switch size {
        case .sized(let size, let scale):
            let key = BlockieKey(address: address, size: size, scale: scale)
            cache[key] = blockie
        case .none:
            sizeLessCache[address] = blockie
        }
    }

    private func cachedBlockie(address: AlphaWallet.Address, size: BlockieSize) -> BlockiesImage? {
        switch size {
        case .sized(let size, let scale):
            let key = BlockieKey(address: address, size: size, scale: scale)
            return cache[key] ?? sizeLessCache[address]
        case .none:
            return sizeLessCache[address]
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
