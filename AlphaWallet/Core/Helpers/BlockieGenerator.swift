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

enum BlockiesImage {
    case image(image: UIImage, isEnsAvatar: Bool)
    case url(url: URL, isEnsAvatar: Bool)

    var isEnsAvatar: Bool {
        switch self {
        case .image(_, let isEnsAvatar):
            return isEnsAvatar
        case .url(_, let isEnsAvatar):
            return isEnsAvatar
        }
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

    func promise(address: AlphaWallet.Address, size: Int = 8, scale: Int = 3) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        return firstly {
            cachedBlockie(address: address, size: .sized(size: size, scale: scale))
        }.recover { _ -> Promise<BlockiesImage> in
            self.fetchEnsAvatar(from: address, ens: nil)
                .get { blockie in
                    self.cacheBlockie(address: address, blockie: blockie, size: .none)
                }.recover { _ -> Promise<BlockiesImage> in
                    self.createBlockiesImage(address: address, size: size, scale: scale).get { blockie in
                        self.cacheBlockie(address: address, blockie: blockie, size: .sized(size: size, scale: scale))
                    }
                }
        }
    }

    func promise(address: AlphaWallet.Address, ens: String, size: Int = 8, scale: Int = 3) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        return firstly {
            cachedBlockie(address: address, size: .sized(size: size, scale: scale))
        }.recover { _ -> Promise<BlockiesImage> in
            self.fetchEnsAvatar(from: address, ens: ens)
                .get { blockie in
                    self.cacheBlockie(address: address, blockie: blockie, size: .none)
                }.recover { _ -> Promise<BlockiesImage> in
                    self.createBlockiesImage(address: address, size: size, scale: scale).get { blockie in
                        self.cacheBlockie(address: address, blockie: blockie, size: .sized(size: size, scale: scale))
                    }
                }
        }
    }

    private func fetchEnsAvatar(from address: AlphaWallet.Address, ens: String?) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        let promise: Promise<String>

        if let ens = ens {
            promise = GetENSTextRecordsCoordinator(server: .forResolvingEns)
                .getENSRecord(for: ens, record: .avatar)
        } else {
            promise = GetENSTextRecordsCoordinator(server: .forResolvingEns)
                .getENSRecord(for: address, record: .avatar)
        }

        return firstly {
            promise
        }.then { url -> Promise<BlockiesImage> in
            return Self.decodeEip155URL(url: url).then { value -> Promise<BlockiesImage> in
                Self.fetchOpenSeaAssetAssetURL(from: value).then { url -> Promise<BlockiesImage> in
                    return Self.fetchEnsAvatar(request: URLRequest(url: url), queue: .main)
                }
            }.recover { _ -> Promise<BlockiesImage> in
                guard let url = URL(string: url) else { return .init(error: AnyError.blockieCreateFailure) }
                return Self.fetchEnsAvatar(request: URLRequest(url: url), queue: .main)
            }
        }
    }

    private static func fetchOpenSeaAssetAssetURL(from value: Eip155URL) -> Promise<URL> {
        return OpenSea.fetchAsset(for: value)
    }

    private static func decodeEip155URL(url: String) -> Promise<Eip155URL> {
        enum AnyError: Error {
            case e_1
        }

        guard let result = eip155URLDecoder.decode(from: url) else {
            return .init(error: AnyError.e_1)
        }
        return .value(result)
    }

    private static func fetchEnsAvatar(request: URLRequest, queue: DispatchQueue) -> Promise<BlockiesImage> {
        Promise { seal in
            queue.async {
                guard let url = request.url else {
                    return seal.reject(TokenImageFetcher.ImageAvailabilityError.notAvailable)
                }

                if url.pathExtension == "svg" {
                    return seal.fulfill(.url(url: url, isEnsAvatar: true))
                }

                let task = URLSession.shared.dataTask(with: request) { data, _, _ in
                    guard let image = data.flatMap({ UIImage(data: $0) }) else {
                        return seal.reject(TokenImageFetcher.ImageAvailabilityError.notAvailable)
                    }

                    seal.fulfill(.image(image: image, isEnsAvatar: true))
                }

                task.resume()
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

    private func cachedBlockie(address: AlphaWallet.Address, size: BlockieSize) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case cacheNotFound
        }

        return Promise { seal in
            var value: BlockiesImage?
            switch size {
            case .sized(let size, let scale):
                let key = BlockieKey(address: address, size: size, scale: scale)
                value = BlockiesGenerator.cache[key]

                if value == nil {
                    value = BlockiesGenerator.sizeLessCache[address]
                }
            case .none:
                value = BlockiesGenerator.sizeLessCache[address]
            }

            if let value = value {
                seal.fulfill(value)
            } else {
                seal.reject(AnyError.cacheNotFound)
            }
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

typealias Eip155URL = (tokenType: TokenInterfaceType?, server: RPCServer?, path: String)
struct eip155URLDecoder {
    static let key = "eip155"

    /// Decoding function for urls like `eip155:1/erc721:0xb7F7F6C52F2e2fdb1963Eab30438024864c313F6/2430`
    static func decode(from string: String) -> Eip155URL? {
        let components = string.components(separatedBy: ":")
        guard components.count >= 3, components[0].contains(eip155URLDecoder.key) else { return .none }
        let chainAndTokenTypeComponents = components[1].components(separatedBy: "/")
        guard chainAndTokenTypeComponents.count == 2 else { return .none }
        let server = chainAndTokenTypeComponents[0].optionalDecimalValue.flatMap({ RPCServer(chainID: $0.intValue) })

        return (tokenType: TokenInterfaceType(rawValue: chainAndTokenTypeComponents[1]), server: server, path: components[2])
    }
}
