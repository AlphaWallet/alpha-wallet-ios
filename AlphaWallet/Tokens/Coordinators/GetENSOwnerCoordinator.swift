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
        //TODO shouldn't caching be based on input instead?
        if let cachedResult = cachedResult(forNode: node) {
            return .value(cachedResult)
        }

        let server = server
        return firstly {
            getResolver(input: input)
        }.then { resolver -> Promise<(AlphaWallet.Address, Bool)> in
            self.isSupportEnsIp10(resolver: resolver).map { (resolver, $0) }
        }.then { resolver, supportsEnsIp10 -> Promise<AlphaWallet.Address> in
            verboseLog("[ENS] Fetch resolver: \(resolver.eip55String) supports ENSIP-10? \(supportsEnsIp10) for input: \(input)")
            if supportsEnsIp10 {
                return self.getENSAddressFromResolverUsingResolve(for: input, node: node, resolver: resolver)
            } else {
                return self.getENSAddressFromResolverUsingAddr(for: input, node: node, resolver: resolver)
            }
        }
    }

    private func isSupportEnsIp10(resolver: AlphaWallet.Address) -> Promise<Bool> {
        let hash = "0x9061b923" //ENSIP-10 resolve(bytes,bytes)"
        return GetInterfaceSupported165Coordinator(forServer: server).getInterfaceSupported165(hash: hash, contract: resolver)
    }

    private func getResolver(input: String) -> Promise<AlphaWallet.Address> {
        let function = GetENSResolverEncode()
        let server = server
        let node = input.lowercased().nameHash
        return firstly {
            callSmartContract(withServer: server, contract: server.ensRegistrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject])
        }.then { result -> Promise<AlphaWallet.Address> in
            if let resolver = (result["0"] as? EthereumAddress).flatMap({ AlphaWallet.Address(address: $0) }) {
                verboseLog("[ENS] fetched resolver: \(resolver) for: \(input) arg: \(node)")
                if Constants.nullAddress.sameContract(as: resolver) && input != "" {
                    //Wildcard resolution https://docs.ens.domains/ens-improvement-proposals/ensip-10-wildcard-resolution
                    let parentInput = input.split(separator: ".").dropFirst().joined(separator: ".")
                    verboseLog("[ENS] fetching parent \(parentInput) resolver again for ENSIP-10. Was: \(resolver) for: \(input) arg: \(node)")
                    return self.getResolver(input: parentInput)
                } else {
                    if Constants.nullAddress.sameContract(as: resolver) {
                        throw AnyError(Web3Error(description: "Null address returned"))
                    } else {
                        return .value(resolver)
                    }
                }
            } else {
                throw AnyError(Web3Error(description: "Error extracting result from \(server.ensRegistrarContract).\(function.name)()"))
            }
        }
    }

    private func getENSAddressFromResolverUsingAddr(for input: String, node: String, resolver: AlphaWallet.Address) -> Promise<AlphaWallet.Address> {
        let function = GetENSRecordWithResolverAddrEncode()
        verboseLog("[ENS] calling function \(function.name) for input: \(input)…")
        return callSmartContract(withServer: server, contract: resolver, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).map { result in
            if let ensAddress = result["0"] as? EthereumAddress {
                verboseLog("[ENS] called function \(function.name) for input: \(input) result: \(ensAddress.address)")
                if Constants.nullAddress.sameContract(as: ensAddress) {
                    throw AnyError(Web3Error(description: "Null address returned"))
                } else {
                    let address = AlphaWallet.Address(address: ensAddress)
                    //Retain self because it's useful to cache the results even if we don't immediately need it now
                    GetENSAddressCoordinator.cache(forNode: node, result: address, server: self.server)
                    return address
                }
            } else {
                throw AnyError(Web3Error(description: "Incorrect data output from ENS resolver"))
            }
        }
    }

    private func getENSAddressFromResolverUsingResolve(for input: String, node: String, resolver: AlphaWallet.Address) -> Promise<AlphaWallet.Address> {
        let addrFunction = GetENSRecordWithResolverAddrEncode()
        let resolveFunction = GetENSRecordWithResolverResolveEncode()
        let dnsEncodedName = dnsEncode(name: input)
        guard let callData = getSmartContractCallData(withServer: server, contract: resolver, functionName: addrFunction.name, abiString: addrFunction.abi, parameters: [node] as [AnyObject]) else {
            struct FailedToBuildCallDataForEnsIp10: Error {}
            return Promise(error: FailedToBuildCallDataForEnsIp10())
        }
        verboseLog("[ENS] addr data calldata: \(callData.hexString)")
        let parameters: [AnyObject] = [
            dnsEncodedName as AnyObject,
            callData as AnyObject,
        ]
        verboseLog("[ENS] calling function \(resolveFunction.name) for input: \(input) DNS-encoded name: \(dnsEncodedName.hex()) callData: \(callData.hex())…")
        return firstly {
            callSmartContract(withServer: server, contract: resolver, functionName: resolveFunction.name, abiString: resolveFunction.abi, parameters: parameters)
        }.map { result in
            if let addressStringAsData = result["0"] as? Data {
                let addressStringLeftPaddedWithZeros = addressStringAsData.hexString
                let addressString = String(addressStringLeftPaddedWithZeros.dropFirst(addressStringLeftPaddedWithZeros.count - 40))
                verboseLog("[ENS] called function \(resolveFunction.name) for input: \(input) result: \(addressString)")
                if let address = AlphaWallet.Address(uncheckedAgainstNullAddress: addressString) {
                    if Constants.nullAddress.sameContract(as: address) {
                        throw AnyError(Web3Error(description: "Null address returned"))
                    } else {
                        //Retain self because it's useful to cache the results even if we don't immediately need it now
                        GetENSAddressCoordinator.cache(forNode: node, result: address, server: self.server)
                        return address
                    }
                } else {
                    throw AnyError(Web3Error(description: "Incorrect data output from ENS resolver"))
                }
            } else {
                throw AnyError(Web3Error(description: "Incorrect data output from ENS resolver"))
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

//"www.xyzindustries.com" -> "[3] w w w [13] x y z i n d u s t r i e s [3] c o m [0]"
//— http://www.tcpipguide.com/free/t_DNSNameNotationandMessageCompressionTechnique.htm
fileprivate func dnsEncode(name: String) -> Data {
    //TODO improve appending
    var result = Data()
    for each in name.split(separator: ".") {
        result.append(Data(bytes: [UInt8(each.count)]))
        let data = each.data(using: .utf8)!
        result.append(data)
    }
    result.append(0)
    return result
}