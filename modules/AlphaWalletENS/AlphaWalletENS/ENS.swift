//
//  ENS.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/7/22.
//

import AlphaWalletAddress
import AlphaWalletCore
import AlphaWalletWeb3
import Combine
import Foundation

public enum SmartContractError: Error {
    case delegateNotFound
    case embedded(Error)
}

public protocol ENSDelegate: AnyObject {
    func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> AnyPublisher<[String: Any], SmartContractError>
    func getSmartContractCallData(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> Data?
    func getInterfaceSupported165Async(server: RPCServer, hash: String, contract: AlphaWallet.Address) async throws -> Bool
}

extension ENSDelegate {
    func callSmartContract(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = []) -> AnyPublisher<[String: Any], SmartContractError> {
        callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters)
    }

    func getSmartContractCallData(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = []) -> Data? {
        getSmartContractCallData(withServer: server, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters)
    }

    func callSmartContractAsync(withServer server: RPCServer, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) async throws -> [String: Any] {
        try await callSmartContract(withServer: server, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters).async()
    }
}

public class ENS {
    //Always Ethereum mainnet's. For now at least
    private static let registrarContract = AlphaWallet.Address(string: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e")!

    public static var isLoggingEnabled = false

    private weak var delegate: ENSDelegate?
    private let server: RPCServer

    public init(delegate: ENSDelegate, server: RPCServer) {
        self.delegate = delegate
        self.server = server
    }

    public func getENSAddress(fromName name: String) async throws -> AlphaWallet.Address {
        //if already an address, send back the address
        if let ethAddress = AlphaWallet.Address(string: name) { return ethAddress }

        //if it does not contain .eth, then it is not a valid ens name
        if !name.contains(".") { throw SmartContractError.embedded(ENSError(description: "Invalid ENS Name")) }

        let resolver = try await getResolver(forName: name)
        let supportsEnsIp10 = try await isSupportEnsIp10(resolver: resolver)
        verboseLog("[ENS] Fetch resolver: \(resolver.eip55String) supports ENSIP-10? \(supportsEnsIp10) for name: \(name)")
        let node = name.lowercased().nameHash
        if supportsEnsIp10 {
            return try await getENSAddressFromResolverUsingResolve(forName: name, node: node, resolver: resolver)
        } else {
            return try await getENSAddressFromResolverUsingAddr(forName: name, node: node, resolver: resolver)
        }
    }

    //Performs a ENS reverse lookup — figure out ENS name from a given Ethereum address — and then forward resolves the ENS name (look up Ethereum address from ENS name) to verify it. This is necessary because:
    // (quoted from https://docs.ens.domains/dapp-developer-guide/resolving-names)
    // > "ENS does not enforce the accuracy of reverse records - for instance, anyone may claim that the name for their address is 'alice.eth'. To be certain that the claim is accurate, you must always perform a forward resolution for the returned name and check it matches the original address."
    public func getName(fromAddress address: AlphaWallet.Address) async throws -> String {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { throw SmartContractError.delegateNotFound }

        //TODO extract get resolver and reverse lookup functions
        let node = address.nameHash
        let resolverFunction = GetENSResolverEncode()
        let server = server
        let resolverResult = try await delegate.callSmartContractAsync(withServer: server, contract: Self.registrarContract, functionName: resolverFunction.name, abiString: resolverFunction.abi, parameters: [node] as [AnyObject])
        guard let resolverEthereumAddress = resolverResult["0"] as? EthereumAddress else {
            let error = ENSError(description: "Error extracting result from \(Self.registrarContract).\(resolverFunction.name)()")
            throw SmartContractError.embedded(error)
        }
        let resolver = AlphaWallet.Address(address: resolverEthereumAddress)
        guard !resolver.isNull else {
            let error = ENSError(description: "Null address returned")
            throw SmartContractError.embedded(error)
        }
        let reverseLookupFunction = ENSReverseLookupEncode()
        let reverseLookupResult = try await delegate.callSmartContractAsync(withServer: server, contract: resolver, functionName: reverseLookupFunction.name, abiString: reverseLookupFunction.abi, parameters: [node] as [AnyObject])
        guard let ensName = reverseLookupResult["0"] as? String, ensName.contains(".") else {
            let error = ENSError(description: "Incorrect data output from ENS resolver")
            throw SmartContractError.embedded(error)
        }
        let resolvedAddress = try await getENSAddress(fromName: ensName)
        if address == resolvedAddress {
            return ensName
        } else {
            throw ENSError(description: "Forward resolution of ENS name found by reverse look up doesn't match")
        }
    }

    public func getTextRecord(forName name: String, recordKey: EnsTextRecordKey) async throws -> String {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { throw SmartContractError.delegateNotFound }
        guard !name.components(separatedBy: ".").isEmpty else {
            throw SmartContractError.embedded(ENSError(description: "\(name) is invalid ENS name"))
        }

        let addr = name.lowercased().nameHash
        let function = GetEnsTextRecord()
        let server = server
        let result = try await delegate.callSmartContractAsync(withServer: server, contract: getENSRecordsContract(forServer: server), functionName: function.name, abiString: function.abi, parameters: [addr as AnyObject, recordKey.rawValue as AnyObject])
        guard let record = result["0"] as? String else { throw ENSError(description: "interface doesn't support for server \(server)") }
        guard !record.isEmpty else { throw ENSError(description: "ENS text record not found for record: \(record) for server: \(server)") }
        return record
    }

    private func isSupportEnsIp10(resolver: AlphaWallet.Address) async throws -> Bool {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { throw SmartContractError.delegateNotFound }

        let hash = "0x9061b923" //ENSIP-10 resolve(bytes,bytes)"
        return try await delegate.getInterfaceSupported165Async(server: server, hash: hash, contract: resolver)
    }

    private func getResolver(forName name: String) async throws -> AlphaWallet.Address {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { throw SmartContractError.delegateNotFound }

        let function = GetENSResolverEncode()
        let server = server
        let node = name.lowercased().nameHash
        let result = try await delegate.callSmartContractAsync(withServer: server, contract: Self.registrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject])
        if let resolver = (result["0"] as? EthereumAddress).flatMap({ AlphaWallet.Address(address: $0) }) {
            verboseLog("[ENS] fetched resolver: \(resolver) for: \(name) arg: \(node)")
            if resolver.isNull && name != "" {
                //Wildcard resolution https://docs.ens.domains/ens-improvement-proposals/ensip-10-wildcard-resolution
                let parentName = name.split(separator: ".").dropFirst().joined(separator: ".")
                verboseLog("[ENS] fetching parent \(parentName) resolver again for ENSIP-10. Was: \(resolver) for: \(name) arg: \(node)")
                return try await getResolver(forName: parentName)
            } else {
                if resolver.isNull {
                    let error = ENSError(description: "Null address returned")
                    throw SmartContractError.embedded(error)
                } else {
                    return resolver
                }
            }
        } else {
            let error = ENSError(description: "Error extracting result from \(Self.registrarContract).\(function.name)()")
            throw SmartContractError.embedded(error)
        }
    }

    private func getENSAddressFromResolverUsingAddr(forName name: String, node: String, resolver: AlphaWallet.Address) async throws -> AlphaWallet.Address {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { throw SmartContractError.delegateNotFound }

        let function = GetENSRecordWithResolverAddrEncode()
        let server = server
        verboseLog("[ENS] calling function \(function.name) for name: \(name)…")
        let result = try await delegate.callSmartContractAsync(withServer: server, contract: resolver, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject])
        guard let ensAddressEthereumAddress = result["0"] as? EthereumAddress else { throw ENSError(description: "Incorrect data output from ENS resolver") }
        let ensAddress = AlphaWallet.Address(address: ensAddressEthereumAddress)
        verboseLog("[ENS] called function \(function.name) for name: \(name) result: \(ensAddress.eip55String)")
        guard !ensAddress.isNull else { throw ENSError(description: "Null address returned") }
        return ensAddress
    }

    private func getENSAddressFromResolverUsingResolve(forName name: String, node: String, resolver: AlphaWallet.Address) async throws -> AlphaWallet.Address {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { throw SmartContractError.delegateNotFound }

        let addrFunction = GetENSRecordWithResolverAddrEncode()
        let resolveFunction = GetENSRecordWithResolverResolveEncode()
        let dnsEncodedName = functional.dnsEncode(name: name)
        guard let callData = try delegate.getSmartContractCallData(withServer: server, contract: resolver, functionName: addrFunction.name, abiString: addrFunction.abi, parameters: [node] as [AnyObject]) else {
            struct FailedToBuildCallDataForEnsIp10: Error {}
            throw SmartContractError.embedded(FailedToBuildCallDataForEnsIp10())
        }
        verboseLog("[ENS] addr data calldata: \(callData.hexString)")
        let parameters: [AnyObject] = [
            dnsEncodedName as AnyObject,
            callData as AnyObject,
        ]
        let server = server
        verboseLog("[ENS] calling function \(resolveFunction.name) for name: \(name) DNS-encoded name: \(dnsEncodedName.hex()) callData: \(callData.hex())…")
        let result = try await delegate.callSmartContractAsync(withServer: server, contract: resolver, functionName: resolveFunction.name, abiString: resolveFunction.abi, parameters: parameters)
        guard let addressStringAsData = result["0"] as? Data else { throw ENSError(description: "Incorrect data output from ENS resolver") }
        let addressStringLeftPaddedWithZeros = addressStringAsData.hexString
        let addressString = String(addressStringLeftPaddedWithZeros.dropFirst(addressStringLeftPaddedWithZeros.count - 40))
        verboseLog("[ENS] called function \(resolveFunction.name) for name: \(name) result: \(addressString)")
        guard let address = AlphaWallet.Address(uncheckedAgainstNullAddress: addressString) else { throw ENSError(description: "Incorrect data output from ENS resolver") }
        guard !address.isNull else { throw ENSError(description: "Null address returned") }
        return address
    }

    private func getENSRecordsContract(forServer server: RPCServer) -> AlphaWallet.Address {
        return AlphaWallet.Address(string: "0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41")!
    }
}

extension ENS {
    enum functional {}
}

fileprivate extension ENS.functional {
    //"www.xyzindustries.com" -> "[3] w w w [13] x y z i n d u s t r i e s [3] c o m [0]"
    //— http://www.tcpipguide.com/free/t_DNSNameNotationandMessageCompressionTechnique.htm
    static func dnsEncode(name: String) -> Data {
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
}
