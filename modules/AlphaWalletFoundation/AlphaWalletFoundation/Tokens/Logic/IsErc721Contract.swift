//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import PromiseKit 

public class IsErc721Contract {
    private let server: RPCServer

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

    private var inFlightPromises: [String: Promise<Bool>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.isErc721Contract")

    public init(forServer server: RPCServer) {
        self.server = server
    }

    func getIsERC721Contract(for contract: AlphaWallet.Address) -> Promise<Bool> {
        firstly {
            .value(server)
        }.then(on: queue, { [weak self, queue] server -> Promise<Bool> in
            if let value = IsErc721Contract.sureItsErc721(contract: contract) {
                return .value(value)
            }

            let key = "\(contract.eip55String)-\(server.chainID)"
            if let promise = self?.inFlightPromises[key] {
                return promise
            } else {
                let function = GetInterfaceSupported165Encode()

                let cryptoKittyPromise = callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [ERC165Hash.onlyKat] as [AnyObject])

                let nonCryptoKittyERC721Promise = callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [ERC165Hash.official] as [AnyObject])

                let nonCryptoKittyERC721WithOldInterfaceHashPromise = callSmartContract(withServer: server, contract: contract, functionName: function.name, abiString: function.abi, parameters: [ERC165Hash.old] as [AnyObject])

                //Slower than theoretically possible because we wait for every promise to be resolved. In theory we can stop when any promise is fulfilled with true. But code is much less elegant
                let promise = firstly {
                    when(resolved: cryptoKittyPromise, nonCryptoKittyERC721Promise, nonCryptoKittyERC721WithOldInterfaceHashPromise)
                }.map(on: queue, { data -> Bool in
                    let isCryptoKitty = cryptoKittyPromise.value?["0"] as? Bool
                    let isNonCryptoKittyERC721 = nonCryptoKittyERC721Promise.value?["0"] as? Bool
                    let isNonCryptoKittyERC721WithOldInterfaceHash = nonCryptoKittyERC721WithOldInterfaceHashPromise.value?["0"] as? Bool
                    if let isCryptoKitty = isCryptoKitty, isCryptoKitty {
                        return true
                    } else if let isNonCryptoKittyERC721 = isNonCryptoKittyERC721, isNonCryptoKittyERC721 {
                        return true
                    } else if let isNonCryptoKittyERC721WithOldInterfaceHash = isNonCryptoKittyERC721WithOldInterfaceHash, isNonCryptoKittyERC721WithOldInterfaceHash {
                        return true
                    } else if isCryptoKitty != nil, isNonCryptoKittyERC721 != nil, isNonCryptoKittyERC721WithOldInterfaceHash != nil {
                        return false
                    } else {
                        throw CastError(actualValue: data, expectedType: Bool.self)
                    }
                }).ensure(on: queue, {
                    self?.inFlightPromises[key] = .none
                })

                self?.inFlightPromises[key] = promise

                return promise
            }
        })
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
