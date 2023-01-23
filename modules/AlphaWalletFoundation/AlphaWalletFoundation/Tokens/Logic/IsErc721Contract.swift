//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import Combine

public class IsErc721Contract {
    private let blockchainProvider: BlockchainProvider

    private struct DoesNotSupportERC165Querying {
        static let bitizen = AlphaWallet.Address(string: "0xb891c4d89c1bf012f0014f56ce523f248a07f714")!
        static let cryptoSaga = AlphaWallet.Address(string: "0xabc7e6c01237e8eef355bba2bf925a730b714d5f")!
    }

    private struct DevconVISouvenir {
        static let polygon = AlphaWallet.Address(string: "0x7Db4de78E6b9A98752B56959611e4cfdA52269D2")!
        static let arbitrum = AlphaWallet.Address(string: "0x7Db4de78E6b9A98752B56959611e4cfdA52269D2")!
        static let optimism = AlphaWallet.Address(string: "0x7Db4de78E6b9A98752B56959611e4cfdA52269D2")!
        static let mainnet = AlphaWallet.Address(string: "0x7522dC5A357891B4dAEC194E285551EA5ea66d09")!
    }

    private struct ERC165Hash {
        static let official = "0x80ac58cd"
        //https://github.com/ethereum/EIPs/commit/d164cb2031503665c7dfbb759272f63c29b2b848
        static let old = "0x6466353c"
        //CryptoKitties' ERC165 interface signature for ERC721 is wrong
        //Using "kat" instead of "cryptokitties" to avoid being mistakenly detected by app review as supporting CryptoKitties
        static let onlyKat = "0x9a20483d"
    }

    private var inFlightPromises: [String: AnyPublisher<Bool, SessionTaskError>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.isErc721Contract")
    private lazy var isInterfaceSupported165 = IsInterfaceSupported165(blockchainProvider: blockchainProvider)

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getIsERC721Contract(for contract: AlphaWallet.Address) -> AnyPublisher<Bool, SessionTaskError> {
        return Just(contract)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue, isInterfaceSupported165, blockchainProvider] contract -> AnyPublisher<Bool, SessionTaskError> in
                if let value = IsErc721Contract.sureItsErc721(contract: contract) {
                    return .just(value)
                }

                let key = "\(contract.eip55String)-\(blockchainProvider.server.chainID)"
                if let promise = self?.inFlightPromises[key] {
                    return promise
                } else {
                    let cryptoKittyPromise = isInterfaceSupported165
                        .getInterfaceSupported165(hash: ERC165Hash.onlyKat, contract: contract)
                        .mapToResult()

                    let nonCryptoKittyERC721Promise = isInterfaceSupported165
                        .getInterfaceSupported165(hash: ERC165Hash.official, contract: contract)
                        .mapToResult()

                    let nonCryptoKittyERC721WithOldInterfaceHashPromise = isInterfaceSupported165
                        .getInterfaceSupported165(hash: ERC165Hash.old, contract: contract)
                        .mapToResult()

                    //Slower than theoretically possible because we wait for every promise to be resolved. In theory we can stop when any promise is fulfilled with true. But code is much less elegant
                    let promise = Publishers.CombineLatest3(cryptoKittyPromise, nonCryptoKittyERC721Promise, nonCryptoKittyERC721WithOldInterfaceHashPromise)
                        .receive(on: queue)
                        .setFailureType(to: SessionTaskError.self)
                        .flatMap { r1, r2, r3 -> AnyPublisher<Bool, SessionTaskError> in
                            let isCryptoKitty = try? r1.get()
                            let isNonCryptoKittyERC721 = try? r2.get()
                            let isNonCryptoKittyERC721WithOldInterfaceHash = try? r3.get()
                            if let isCryptoKitty = isCryptoKitty, isCryptoKitty {
                                return .just(true)
                            } else if let isNonCryptoKittyERC721 = isNonCryptoKittyERC721, isNonCryptoKittyERC721 {
                                return .just(true)
                            } else if let isNonCryptoKittyERC721WithOldInterfaceHash = isNonCryptoKittyERC721WithOldInterfaceHash, isNonCryptoKittyERC721WithOldInterfaceHash {
                                return .just(true)
                            } else if isCryptoKitty != nil, isNonCryptoKittyERC721 != nil, isNonCryptoKittyERC721WithOldInterfaceHash != nil {
                                return .just(false)
                            } else {
                                return .just(false)
                            }
                        }.handleEvents(receiveCompletion: { _ in self?.inFlightPromises[key] = .none })
                        .share()
                        .eraseToAnyPublisher()

                    self?.inFlightPromises[key] = promise

                    return promise
                }
            }.eraseToAnyPublisher()
    }

    private static func sureItsErc721(contract: AlphaWallet.Address) -> Bool? {
        let contracts: [AlphaWallet.Address] = [
            DoesNotSupportERC165Querying.bitizen,
            DoesNotSupportERC165Querying.cryptoSaga,
            DevconVISouvenir.mainnet,
            DevconVISouvenir.arbitrum,
            DevconVISouvenir.optimism,
            DevconVISouvenir.polygon
        ]

        if contracts.contains(contract) {
            return true
        }

        return nil
    }
}
