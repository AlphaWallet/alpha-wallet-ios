//
//  BlockieGenerator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.11.2020.
//

import Foundation
import BlockiesSwift
import PromiseKit
import UIKit.UIImage
import Combine

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

    /// Address related icons cache with image size and scale
    private static var cache: [BlockieKey: BlockiesImage] = [:]

    /// Address related icons cache without image size. Cache is using for determine images without sizes and scales, fetched out from OpenSea
    private static var sizeLessCache: [AlphaWallet.Address: BlockiesImage] = [:]

    private let openSea: OpenSea

    init(openSea: OpenSea) {
        self.openSea = openSea
    }

    func getBlockie(address: AlphaWallet.Address, ens: String? = nil, size: Int = 8, scale: Int = 3, fallbackImage: BlockiesImage = BlockiesImage.defaulBlockieImage) -> AnyPublisher<BlockiesImage, Never> {
        return promise(address: address, ens: ens, size: size, scale: size).publisher
            .receive(on: RunLoop.main)
            .prepend(fallbackImage)
            .replaceError(with: fallbackImage)
            .eraseToAnyPublisher()
    }

    func promise(address: AlphaWallet.Address, ens: String? = nil, size: Int = 8, scale: Int = 3) -> Promise<BlockiesImage> {
        if let cached = cachedBlockie(address: address, size: .sized(size: size, scale: scale)) {
            return .value(cached)
        }

        return firstly {
            fetchEnsAvatar(from: address, ens: ens)
        }.get { blockie in
            self.cacheBlockie(address: address, blockie: blockie, size: .none)
        }.recover { _ -> Promise<BlockiesImage> in
            self.createBlockiesImage(address: address, size: size, scale: scale).get { blockie in
                self.cacheBlockie(address: address, blockie: blockie, size: .sized(size: size, scale: scale))
            }
        }
    }

    private func fetchEnsAvatar(from address: AlphaWallet.Address, ens: String?) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        let promise: Promise<String>

        if let ens = ens {
            promise = GetENSTextRecord(server: .forResolvingEns)
                .getENSRecord(forName: ens, record: .avatar)
        } else {
            promise = GetENSTextRecord(server: .forResolvingEns)
                .getENSRecord(forAddress: address, record: .avatar)
        }

        return firstly {
            promise
        }.then { url -> Promise<BlockiesImage> in
            guard let result = eip155URLCoder.decode(from: url) else {
                return .init(error: TokenImageFetcher.ImageAvailabilityError.notAvailable)
            }
            return firstly {
                self.openSea.fetchAssetImageUrl(for: result, server: .main)
            }.map { url -> BlockiesImage in
                .url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true)
            }.recover { _ -> Promise<BlockiesImage> in
                guard let url = URL(string: url) else { return .init(error: AnyError.blockieCreateFailure) }
                return .value(.url(url: WebImageURL(url: url, rewriteGoogleContentSizeUrl: .s120), isEnsAvatar: true))
            }
        }
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

    private func createBlockiesImage(address: AlphaWallet.Address, size: Int, scale: Int) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        return Promise { seal in
            DispatchQueue.global().async {
                let blockies = Blockies(seed: address.eip55String, size: size, scale: scale)
                DispatchQueue.main.async {
                    if let image = blockies.createImage() {
                        seal.fulfill(.image(image: image, isEnsAvatar: false))
                    } else {
                        seal.reject(AnyError.blockieCreateFailure)
                    }
                }
            }
        }
    }
}
