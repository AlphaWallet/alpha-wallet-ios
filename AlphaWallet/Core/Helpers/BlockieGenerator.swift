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

enum BlockiesImage {
    case image(image: UIImage, isEnsAvatar: Bool)
    case url(url: WebImageURL, isEnsAvatar: Bool)

    var isEnsAvatar: Bool {
        switch self {
        case .image(_, let isEnsAvatar):
            return isEnsAvatar
        case .url(_, let isEnsAvatar):
            return isEnsAvatar
        }
    }

    static var defaulBlockieImage: BlockiesImage {
        return .image(image: R.image.tokenPlaceholderLarge()!, isEnsAvatar: false)
    }
}

extension BlockiesImage: Hashable { }

class BlockiesGenerator {
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
    private static var cache: [BlockieKey: BlockiesImage] = [:]
    /// Address related icons cache without image size. Cache is using for determine images without sizes and scales, fetched out from OpenSea
    private static var sizeLessCache: [AlphaWallet.Address: BlockiesImage] = [:]
    private let storage: EnsRecordsStorage
    private lazy var ensTextRecordFetcher = GetEnsTextRecord(server: .forResolvingEns, storage: storage)
    private let openSea: OpenSea

    init(openSea: OpenSea, storage: EnsRecordsStorage) {
        self.openSea = openSea
        self.storage = storage
    }

    func getBlockieOrEnsAvatarImage(address: AlphaWallet.Address, ens: String? = nil, size: Int = 8, scale: Int = 3, fallbackImage: BlockiesImage) -> AnyPublisher<BlockiesImage, Never> {
        return getBlockieOrEnsAvatarImage(address: address, ens: ens, size: size, scale: size)
            .prepend(fallbackImage)
            .replaceError(with: fallbackImage)
            .eraseToAnyPublisher()
    }

    func getBlockieOrEnsAvatarImage(address: AlphaWallet.Address, ens: String? = nil, size: Int = 8, scale: Int = 3) -> AnyPublisher<BlockiesImage, SmartContractError> {
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
            BlockiesGenerator.cache[key] = blockie
        case .none:
            BlockiesGenerator.sizeLessCache[address] = blockie
        }
    }

    private func cachedBlockie(address: AlphaWallet.Address, size: BlockieSize) -> BlockiesImage? {
        switch size {
        case .sized(let size, let scale):
            let key = BlockieKey(address: address, size: size, scale: scale)
            return BlockiesGenerator.cache[key] ?? BlockiesGenerator.sizeLessCache[address]
        case .none:
            return BlockiesGenerator.sizeLessCache[address]
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

extension GetEnsTextRecord {

    enum Eip155URLOrWebImageURL {
        case image(image: BlockiesImage, raw: String)
        case eip155(url: Eip155URL, raw: String)
    }

    func getEnsAvatar(for address: AlphaWallet.Address, ens: String?) -> AnyPublisher<Eip155URLOrWebImageURL, SmartContractError> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        let publisher: AnyPublisher<String, SmartContractError>
        if let ens = ens {
            publisher = getENSRecord(forName: ens, record: .avatar)
        } else {
            publisher = getENSRecord(forAddress: address, record: .avatar)
        }

        return publisher.flatMap { _url -> AnyPublisher<Eip155URLOrWebImageURL, SmartContractError> in
            //NOTE: once open sea image url cached it will be here as `url`, so the next time we willn't decode it as eip155 and return it as it is
            guard let result = eip155URLCoder.decode(from: _url) else {
                guard let url = URL(string: _url) else {
                    return .fail(.embeded(AnyError.blockieCreateFailure))
                }
                //NOTE: fallback to URL in case if result isn't eip155
                return .just(.image(image: .url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true), raw: _url))
            }

            return .just(.eip155(url: result, raw: _url))
        }.eraseToAnyPublisher()
    }
}
