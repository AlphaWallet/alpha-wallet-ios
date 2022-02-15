// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import Result
import web3swift
import PromiseKit

//This class performs a ENS reverse lookup — figure out ENS name from a given Ethereum address — and then forward resolves the ENS name (look up Ethereum address from ENS name) to verify it. This is necessary because:
// (quoted from https://docs.ens.domains/dapp-developer-guide/resolving-names)
// > "ENS does not enforce the accuracy of reverse records - for instance, anyone may claim that the name for their address is 'alice.eth'. To be certain that the claim is accurate, you must always perform a forward resolution for the returned name and check it matches the original address."
struct ENSReverseLookupCoordinator: CachedEnsResolutionServiceType {
    private static var resultsCache = [ENSLookupKey: String]()

    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func cachedEnsValue(for input: AlphaWallet.Address) -> String? {
        let node = "\(input.eip55String.drop0x).addr.reverse".lowercased().nameHash
        return cachedResult(forNode: node)
    }

    //TODO make calls from multiple callers at the same time for the same address more efficient
    func getENSNameFromResolver(forAddress input: AlphaWallet.Address) -> Promise<String> {
        let node = "\(input.eip55String.drop0x).addr.reverse".lowercased().nameHash
        if let cachedResult = cachedResult(forNode: node) {
            return .value(cachedResult)
        }

        let function = GetENSResolverEncode()
        let server = server
        return callSmartContract(withServer: server, contract: server.ensRegistrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).then { result -> Promise<String> in
            if let resolver = result["0"] as? EthereumAddress {
                if Constants.nullAddress.sameContract(as: resolver) {
                    return .init(error: AnyError(Web3Error(description: "Null address returned")))
                } else {
                    let function = ENSReverseLookupEncode()
                    return callSmartContract(withServer: server, contract: AlphaWallet.Address(address: resolver), functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).then { result -> Promise<String> in
                        guard let ensName = result["0"] as? String, ensName.contains(".") else {
                            return .init(error: AnyError(Web3Error(description: "Incorrect data output from ENS resolver")))
                        }
                        return GetENSAddressCoordinator(server: server)
                            .getENSAddressFromResolver(for: ensName)
                            .map { address -> String in
                                if input == address {
                                    ENSReverseLookupCoordinator.cache(forNode: node, result: ensName, server: server)
                                    return ensName
                                } else {
                                    throw AnyError(Web3Error(description: "Forward resolution of ENS name found by reverse look up doesn't match"))
                                }
                            }
                    }
                }
            } else {
                return .init(error: AnyError(Web3Error(description: "Error extracting result from \(server.ensRegistrarContract).\(function.name)()")))
            }
        }
    }

    private func cachedResult(forNode node: String) -> String? {
        return ENSReverseLookupCoordinator.resultsCache[ENSLookupKey(name: node, server: server)]
    }

    private static func cache(forNode node: String, result: String, server: RPCServer) {
        ENSReverseLookupCoordinator.resultsCache[ENSLookupKey(name: node, server: server)] = result
    }
}
