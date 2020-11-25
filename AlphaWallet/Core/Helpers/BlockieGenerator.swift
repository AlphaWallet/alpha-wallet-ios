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
    private static var cache: [AlphaWallet.Address: BlockiesImage] = [:]

    func promise(address: AlphaWallet.Address) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        return firstly {
            cachedBlockie(address: address)
        }.recover { _ -> Promise<BlockiesImage> in
            return Promise { seal in
                self.createBlockiesImage(address: address).then { blockie -> Promise<BlockiesImage> in
                    self.cacheBlockie(address: address, blockie: blockie)

                    return .value(blockie)
                }.done { image in
                    seal.fulfill(image)
                }.catch { error in
                    seal.reject(error)
                }
            }
        }
    }

    private func cacheBlockie(address: AlphaWallet.Address, blockie: BlockiesImage) {
        BlockiesGenerator.cache[address] = blockie
    }

    private func cachedBlockie(address: AlphaWallet.Address) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case cacheNotFound
        }

        return Promise { seal in
            if let value = BlockiesGenerator.cache[address] {
                seal.fulfill(value)
            } else {
                seal.reject(AnyError.cacheNotFound)
            }
        }
    }

    private func createBlockiesImage(address: AlphaWallet.Address) -> Promise<BlockiesImage> {
        enum AnyError: Error {
            case blockieCreateFailure
        }

        return Promise { seal in
            DispatchQueue.global().async {
                let blockies = Blockies(seed: address.eip55String, size: 8, scale: 3)
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
