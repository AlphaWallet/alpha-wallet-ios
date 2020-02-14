// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Result
import web3swift

//This class performs a ENS reverse lookup — figure out Ethereum address from a given ENS name — and then forward resolves the ENS name (look up Ethereum address from ENS name) to verify it. This is necessary because:
// (quoted from https://docs.ens.domains/dapp-developer-guide/resolving-names)
// > "ENS does not enforce the accuracy of reverse records - for instance, anyone may claim that the name for their address is 'alice.eth'. To be certain that the claim is accurate, you must always perform a forward resolution for the returned name and check it matches the original address."
class ENSReverseLookupCoordinator {
    private struct ENSLookupKey: Hashable {
        let name: String
        let server: RPCServer
    }

    private static var resultsCache = [ENSLookupKey: String]()

    private var toStartResolvingEnsNameTimer: Timer?
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func getENSNameFromResolver(
            forAddress input: AlphaWallet.Address,
            completion: @escaping (Result<String, AnyError>) -> Void
    ) {
        let node = "\(input.eip55String.drop0x).addr.reverse".lowercased().nameHash
        if let cachedResult = cachedResult(forNode: node) {
            return completion(.success(cachedResult))
        }

        let function = GetENSResolverEncode()
        callSmartContract(withServer: server, contract: server.ensRegistrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).done { result in
            if let resolver = result["0"] as? EthereumAddress {
                if Constants.nullAddress.sameContract(as: resolver) {
                    completion(.failure(AnyError(Web3Error(description: "Null address returned"))))
                } else {
                    let function = ENSReverseLookupEncode()
                    callSmartContract(withServer: self.server, contract: AlphaWallet.Address(address: resolver), functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).done { result in
                        guard let ensName = result["0"] as? String, ensName.contains(".") else {
                            completion(.failure(AnyError(Web3Error(description: "Incorrect data output from ENS resolver"))))
                            return
                        }
                        GetENSAddressCoordinator(server: self.server).getENSAddressFromResolver(for: ensName) { result in
                            if let addressFromForwardResolution = result.value, EthereumAddress(address: input) == addressFromForwardResolution {
                                self.cache(forNode: node, result: ensName)
                                completion(.success(ensName))
                            } else {
                                completion(.failure(AnyError(Web3Error(description: "Forward resolution of ENS name found by reverse look up doesn't match"))))
                            }
                        }
                    }.cauterize()

                }
            } else {
                completion(.failure(AnyError(Web3Error(description: "Error extracting result from \(self.server.ensRegistrarContract).\(function.name)()"))))
            }
        }.catch {
            completion(.failure(AnyError($0)))
        }
    }

    private func cachedResult(forNode node: String) -> String? {
        return ENSReverseLookupCoordinator.resultsCache[ENSLookupKey(name: node, server: server)]
    }

    private func cache(forNode node: String, result: String) {
        ENSReverseLookupCoordinator.resultsCache[ENSLookupKey(name: node, server: server)] = result
    }
}
