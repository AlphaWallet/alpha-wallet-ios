//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import Combine

public actor IsErc721Contract {
    private let blockchainProvider: BlockchainProvider

    private struct ERC165Hash {
        static let official = "0x80ac58cd"
        //https://github.com/ethereum/EIPs/commit/d164cb2031503665c7dfbb759272f63c29b2b848
        static let old = "0x6466353c"
        //CryptoKitties' ERC165 interface signature for ERC721 is wrong
        //Using "kat" instead of "cryptokitties" to avoid being mistakenly detected by app review as supporting CryptoKitties
        static let onlyKat = "0x9a20483d"
    }

    private var inFlightTasks: [String: Task<Bool, Error>] = [:]
    private lazy var isInterfaceSupported165 = IsInterfaceSupported165(blockchainProvider: blockchainProvider)

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    private func setTask(_ task: Task<Bool, Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    nonisolated func getIsERC721Contract(for contract: AlphaWallet.Address) async throws -> Bool {
        if let value = functional.sureItsErc721(contract: contract) {
            return value
        }

        let key = "\(contract.eip55String)-\(blockchainProvider.server.chainID)"
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<Bool, Error> {
                if let isNonCryptoKittyERC721 = try? await isInterfaceSupported165.getInterfaceSupported165(hash: ERC165Hash.official, contract: contract), isNonCryptoKittyERC721 {
                    return true
                }
                if let isCryptoKitty = try? await isInterfaceSupported165.getInterfaceSupported165(hash: ERC165Hash.onlyKat, contract: contract), isCryptoKitty {
                    return true
                }
                if let isNonCryptoKittyERC721WithOldInterfaceHash = try? await isInterfaceSupported165.getInterfaceSupported165(hash: ERC165Hash.old, contract: contract), isNonCryptoKittyERC721WithOldInterfaceHash {
                    return true
                }
                return false
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }
}

extension IsErc721Contract {
    enum functional {}
}

fileprivate extension IsErc721Contract.functional {
    struct DoesNotSupportERC165Querying {
        static let bitizen = AlphaWallet.Address(string: "0xb891c4d89c1bf012f0014f56ce523f248a07f714")!
        static let cryptoSaga = AlphaWallet.Address(string: "0xabc7e6c01237e8eef355bba2bf925a730b714d5f")!
    }

    struct DevconVISouvenir {
        static let polygon = AlphaWallet.Address(string: "0x7Db4de78E6b9A98752B56959611e4cfdA52269D2")!
        static let arbitrum = AlphaWallet.Address(string: "0x7Db4de78E6b9A98752B56959611e4cfdA52269D2")!
        static let optimism = AlphaWallet.Address(string: "0x7Db4de78E6b9A98752B56959611e4cfdA52269D2")!
        static let mainnet = AlphaWallet.Address(string: "0x7522dC5A357891B4dAEC194E285551EA5ea66d09")!
    }

    static func sureItsErc721(contract: AlphaWallet.Address) -> Bool? {
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
