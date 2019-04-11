//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import PromiseKit
import Result
import TrustKeystore
import web3swift

class GetIsERC721ContractCoordinator {
    private let server: RPCServer

    private struct DoesNotSupportERC165Querying {
        static let bitizen = "0xb891c4d89c1bf012f0014f56ce523f248a07f714"
        static let cryptoSaga = "0xabc7e6c01237e8eef355bba2bf925a730b714d5f"
    }

    private struct ERC165Hash {
        static let official = "0x80ac58cd"
        //https://github.com/ethereum/EIPs/commit/d164cb2031503665c7dfbb759272f63c29b2b848
        static let old = "0x6466353c"
        //CryptoKitties' ERC165 interface signature for ERC721 is wrong
        static let onlyCryptoKitty = "0x9a20483d"
    }

    init(forServer server: RPCServer) {
        self.server = server
    }

    func getIsERC721Contract(
            for contract: Address,
            completion: @escaping (ResultResult<Bool, AnyError>.t) -> Void
    ) {
        if contract.eip55String.sameContract(as: DoesNotSupportERC165Querying.bitizen) {
            completion(.success(true))
            return
        }
        if contract.eip55String.sameContract(as: DoesNotSupportERC165Querying.cryptoSaga) {
            completion(.success(true))
            return
        }

        guard let contractAddress = EthereumAddress(contract.eip55String) else {
            completion(.failure(AnyError(Web3Error(description: "Error converting contract address: \(contract.eip55String)"))))
            return
        }

        guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)"))))
            return
        }

        let web3 = web3swift.web3(provider: webProvider)
        let function = GetIsERC721()
        guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: function.abi, at: contractAddress, options: web3.options) else {
            completion(.failure(AnyError(Web3Error(description: "Error creating web3swift contract instance to call \(function.name)()"))))
            return
        }

        guard let cryptoKittyPromise = contractInstance.method(function.name, parameters: [ERC165Hash.onlyCryptoKitty] as [AnyObject], options: nil)?.callPromise(options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String) with params: \(ERC165Hash.onlyCryptoKitty)"))))
            return
        }

        guard let nonCryptoKittyERC721Promise = contractInstance.method(function.name, parameters: [ERC165Hash.official] as [AnyObject], options: nil)?.callPromise(options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String) with params: \(ERC165Hash.official)"))))
            return
        }

        guard let nonCryptoKittyERC721WithOldInterfaceHashPromise = contractInstance.method(function.name, parameters: [ERC165Hash.old] as [AnyObject], options: nil)?.callPromise(options: nil) else {
            completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String) with params: \(ERC165Hash.old)"))))
            return
        }

        //Slower than theoretically possible because we wait for every promise to be resolved. In theory we can stop when any promise is fulfilled with true. But code is much less elegant
        firstly {
            when(resolved: cryptoKittyPromise, nonCryptoKittyERC721Promise, nonCryptoKittyERC721WithOldInterfaceHashPromise)
        }.done { results in
            let isCryptoKitty = cryptoKittyPromise.value?["0"] as? Bool
            let isNonCryptoKittyERC721 = nonCryptoKittyERC721Promise.value?["0"] as? Bool
            let isNonCryptoKittyERC721WithOldInterfaceHash = nonCryptoKittyERC721WithOldInterfaceHashPromise.value?["0"] as? Bool
            if let isCryptoKitty = isCryptoKitty, isCryptoKitty {
                completion(.success(true))
            } else if let isNonCryptoKittyERC721 = isNonCryptoKittyERC721, isNonCryptoKittyERC721 {
                completion(.success(true))
            } else if let isNonCryptoKittyERC721WithOldInterfaceHash = isNonCryptoKittyERC721WithOldInterfaceHash, isNonCryptoKittyERC721WithOldInterfaceHash {
                completion(.success(true))
            } else if isCryptoKitty != nil, isNonCryptoKittyERC721 != nil, isNonCryptoKittyERC721WithOldInterfaceHash != nil {
                completion(.success(false))
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)()"))))
            }
        }
    }
}
