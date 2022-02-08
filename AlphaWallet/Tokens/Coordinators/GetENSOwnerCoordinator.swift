//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import CryptoSwift
import Result
import web3swift
import PromiseKit

//https://github.com/ethereum/EIPs/blob/master/EIPS/eip-137.md
extension String {
    var nameHash: String {
        var node = [UInt8].init(repeating: 0x0, count: 32)
        if !self.isEmpty {
            node = self.split(separator: ".")
                .map { Array($0.utf8).sha3(.keccak256) }
                .reversed()
                .reduce(node) { return ($0 + $1).sha3(.keccak256) }
        }
        return "0x" + node.toHexString()
    }
}

class GetENSAddressCoordinator: CachebleAddressResolutionServiceType {

    private static var resultsCache: [ENSLookupKey: AlphaWallet.Address] = [:]
    private (set) var server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func cachedAddressValue(for input: String) -> AlphaWallet.Address? {
        let node = input.lowercased().nameHash
        return cachedResult(forNode: node)
    }

    func getENSAddressFromResolver(for input: String) -> Promise<AlphaWallet.Address> {
        //if already an address, send back the address
        if let ethAddress = AlphaWallet.Address(string: input) {
            return .value(ethAddress)
        }

        //if it does not contain .eth, then it is not a valid ens name
        if !input.contains(".") {
            return .init(error: AnyError(Web3Error(description: "Invalid ENS Name")))
        }

        let node = input.lowercased().nameHash
        if let cachedResult = cachedResult(forNode: node) {
            return .value(cachedResult)
        }

        let function = GetENSResolverEncode()
        let server = server
        return callSmartContract(withServer: server, contract: server.ensRegistrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).then { result -> Promise<AlphaWallet.Address> in
            //if null address is returned (as 0) we count it as invalid
            //this is because it is not assigned to an ENS and puts the user in danger of sending funds to null
            if let resolver = result["0"] as? EthereumAddress {
                verboseLog("[ENS] fetched resolver: \(resolver) for: \(input) arg: \(node)")
                if Constants.nullAddress.sameContract(as: resolver) {
                    return .init(error: AnyError(Web3Error(description: "Null address returned")))
                } else {
                    let function = GetENSRecordFromResolverEncode()
                    return callSmartContract(withServer: server, contract: AlphaWallet.Address(address: resolver), functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).map { result in
                        if let ensAddress = result["0"] as? EthereumAddress {
                            if Constants.nullAddress.sameContract(as: ensAddress) {
                                throw AnyError(Web3Error(description: "Null address returned"))
                            } else {
                                //Retain self because it's useful to cache the results even if we don't immediately need it now
                                let adress = AlphaWallet.Address(address: ensAddress)

                                GetENSAddressCoordinator.cache(forNode: node, result: adress, server: server)
                                return adress
                            }
                        } else {
                            throw AnyError(Web3Error(description: "Incorrect data output from ENS resolver"))
                        }
                    }
                }
            } else {
                return .init(error: AnyError(Web3Error(description: "Error extracting result from \(server.ensRegistrarContract).\(function.name)()")))
            }
        }
    }

    private func cachedResult(forNode node: String) -> AlphaWallet.Address? {
        return GetENSAddressCoordinator.resultsCache[ENSLookupKey(name: node, server: server)]
    }

    private static func cache(forNode node: String, result: AlphaWallet.Address, server: RPCServer) {
        GetENSAddressCoordinator.resultsCache[ENSLookupKey(name: node, server: server)] = result
    }
}
