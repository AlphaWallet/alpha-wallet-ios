//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import PromiseKit
import Result
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
        //Using "kat" instead of "cryptokitties" to avoid being mistakenly detected by app review as supporting CryptoKitties
        static let onlyKat = "0x9a20483d"
    }
    private let queue: DispatchQueue
    init(forServer server: RPCServer, queue: DispatchQueue = .global()) {
        self.server = server
        self.queue = queue
    }

    func getIsERC721Contract(
            for contract: AlphaWallet.Address,
            completion: @escaping (ResultResult<Bool, AnyError>.t) -> Void
    ) {
        let server = self.server
        queue.async {
            if contract.sameContract(as: DoesNotSupportERC165Querying.bitizen) {
                completion(.success(true))
                return
            }
            if contract.sameContract(as: DoesNotSupportERC165Querying.cryptoSaga) {
                completion(.success(true))
                return
            }

            //TODO use callSmartContract() instead

            guard let webProvider = Web3HttpProvider(server.rpcURL, network: server.web3Network) else {
                completion(.failure(AnyError(Web3Error(description: "Error creating web provider for: \(server.rpcURL) + \(server.web3Network)"))))
                return
            }

            let configuration = webProvider.session.configuration
            configuration.timeoutIntervalForRequest = TokensDataStore.fetchContractDataTimeout
            configuration.timeoutIntervalForResource = TokensDataStore.fetchContractDataTimeout
            let session = URLSession(configuration: configuration)
            webProvider.session = session

            let contractAddress = EthereumAddress(address: contract)
            let web3 = web3swift.web3(provider: webProvider)
            let function = GetInterfaceSupported165Encode()
            guard let contractInstance = web3swift.web3.web3contract(web3: web3, abiString: function.abi, at: contractAddress) else {
                completion(.failure(AnyError(Web3Error(description: "Error creating web3swift contract instance to call \(function.name)()"))))
                return
            }

            guard let cryptoKittyPromise = contractInstance.method(function.name, parameters: [ERC165Hash.onlyKat] as [AnyObject])?.callPromise() else {
                completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String) with params: \(ERC165Hash.onlyKat)"))))
                return
            }

            guard let nonCryptoKittyERC721Promise = contractInstance.method(function.name, parameters: [ERC165Hash.official] as [AnyObject])?.callPromise() else {
                completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String) with params: \(ERC165Hash.official)"))))
                return
            }

            guard let nonCryptoKittyERC721WithOldInterfaceHashPromise = contractInstance.method(function.name, parameters: [ERC165Hash.old] as [AnyObject])?.callPromise() else {
                completion(.failure(AnyError(Web3Error(description: "Error calling \(function.name)() on \(contract.eip55String) with params: \(ERC165Hash.old)"))))
                return
            }

            //Slower than theoretically possible because we wait for every promise to be resolved. In theory we can stop when any promise is fulfilled with true. But code is much less elegant
            firstly {
                when(resolved: cryptoKittyPromise, nonCryptoKittyERC721Promise, nonCryptoKittyERC721WithOldInterfaceHashPromise)
            }.done(on: self.queue) { _ in
                let isCryptoKitty = cryptoKittyPromise.value?["0"] as? Bool
                let isNonCryptoKittyERC721 = nonCryptoKittyERC721Promise.value?["0"] as? Bool
                let isNonCryptoKittyERC721WithOldInterfaceHash = nonCryptoKittyERC721WithOldInterfaceHashPromise.value?["0"] as? Bool
                if let isCryptoKitty = isCryptoKitty, isCryptoKitty {
                    DispatchQueue.main.async {
                        completion(.success(true))
                    }
                } else if let isNonCryptoKittyERC721 = isNonCryptoKittyERC721, isNonCryptoKittyERC721 {
                    DispatchQueue.main.async {
                        completion(.success(true))
                    }
                } else if let isNonCryptoKittyERC721WithOldInterfaceHash = isNonCryptoKittyERC721WithOldInterfaceHash, isNonCryptoKittyERC721WithOldInterfaceHash {
                    DispatchQueue.main.async {
                        completion(.success(true))
                    }
                } else if isCryptoKitty != nil, isNonCryptoKittyERC721 != nil, isNonCryptoKittyERC721WithOldInterfaceHash != nil {
                    DispatchQueue.main.async {
                        completion(.success(false))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(contract.eip55String).\(function.name)()"))))
                    }
                }
            }
        }
    }
}
