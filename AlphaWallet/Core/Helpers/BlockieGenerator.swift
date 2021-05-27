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

typealias BlockiesImage = UIImage

class BlockiesGenerator {
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

    private static var cache: [BlockieKey: BlockiesImage] = [:]

    func promise(address: AlphaWallet.Address, size: Int = 8, scale: Int = 3) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        return firstly {
            cachedBlockie(address: address, size: size, scale: scale)
        }.recover { _ -> Promise<BlockiesImage> in
            return Promise { seal in
                self.createBlockiesImage(address: address, size: size, scale: scale).then { blockie -> Promise<BlockiesImage> in
                    self.cacheBlockie(address: address, blockie: blockie, size: size, scale: scale)

                    return .value(blockie)
                }.done { image in
                    seal.fulfill(image)
                }.catch { error in
                    seal.reject(error)
                }
            }
        }
    }

    private func cacheBlockie(address: AlphaWallet.Address, blockie: BlockiesImage, size: Int, scale: Int) {
        let key = BlockieKey(address: address, size: size, scale: scale)
        BlockiesGenerator.cache[key] = blockie
    }

    private func cachedBlockie(address: AlphaWallet.Address, size: Int, scale: Int) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case cacheNotFound
        }

        return Promise { seal in
            let key = BlockieKey(address: address, size: size, scale: scale)
            if let value = BlockiesGenerator.cache[key] {
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
                        seal.fulfill(image)
                    } else {
                        seal.reject(AnyError.blockieCreateFailure)
                    }
                }
            }
        }
    }
}
