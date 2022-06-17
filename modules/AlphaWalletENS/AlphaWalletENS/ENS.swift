//
//  ENS.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/7/22.
//

import Foundation
import AlphaWalletAddress
import PromiseKit
import Result
import web3swift

public typealias ChainId = Int

public protocol ENSDelegate: AnyObject {
    func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject], timeout: TimeInterval?) -> Promise<[String: Any]>
    func getSmartContractCallData(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject], timeout: TimeInterval?) -> Data?
    func getInterfaceSupported165(chainId: Int, hash: String, contract: AlphaWallet.Address) -> Promise<Bool>
}

extension ENSDelegate {
    func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [], timeout: TimeInterval? = nil) -> Promise<[String: Any]> {
        callSmartContract(withChainId: chainId, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters, timeout: timeout)
    }

    func getSmartContractCallData(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = [], timeout: TimeInterval? = nil) -> Data? {
        getSmartContractCallData(withChainId: chainId, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters, timeout: timeout)
    }
}

public class ENS {
    //Always Ethereum mainnet's. For now at least
    private static let registrarContract = AlphaWallet.Address(string: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e")!

    public static var isLoggingEnabled = false

    weak private var delegate: ENSDelegate?
    private var chainId: ChainId

    public init(delegate: ENSDelegate, chainId: ChainId) {
        self.delegate = delegate
        self.chainId = chainId
    }

    public func getENSAddress(fromName name: String) -> Promise<AlphaWallet.Address> {
        //if already an address, send back the address
        if let ethAddress = AlphaWallet.Address(string: name) {
            return .value(ethAddress)
        }

        //if it does not contain .eth, then it is not a valid ens name
        if !name.contains(".") {
            return .init(error: AnyError(ENSError(description: "Invalid ENS Name")))
        }

        return firstly {
            getResolver(forName: name)
        }.then { resolver -> Promise<(AlphaWallet.Address, Bool)> in
            self.isSupportEnsIp10(resolver: resolver).map { (resolver, $0) }
        }.then { resolver, supportsEnsIp10 -> Promise<AlphaWallet.Address> in
            verboseLog("[ENS] Fetch resolver: \(resolver.eip55String) supports ENSIP-10? \(supportsEnsIp10) for name: \(name)")
            let node = name.lowercased().nameHash
            if supportsEnsIp10 {
                return self.getENSAddressFromResolverUsingResolve(forName: name, node: node, resolver: resolver)
            } else {
                return self.getENSAddressFromResolverUsingAddr(forName: name, node: node, resolver: resolver)
            }
        }
    }

    //Performs a ENS reverse lookup — figure out ENS name from a given Ethereum address — and then forward resolves the ENS name (look up Ethereum address from ENS name) to verify it. This is necessary because:
    // (quoted from https://docs.ens.domains/dapp-developer-guide/resolving-names)
    // > "ENS does not enforce the accuracy of reverse records - for instance, anyone may claim that the name for their address is 'alice.eth'. To be certain that the claim is accurate, you must always perform a forward resolution for the returned name and check it matches the original address."
    public func getName(fromAddress address: AlphaWallet.Address) -> Promise<String> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return Promise { _ in } }

        let node = address.nameHash
        let function = GetENSResolverEncode()
        let chainId = chainId
        return firstly {
            delegate.callSmartContract(withChainId: chainId, contract: Self.registrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject])
        }.then { result -> Promise<[String: Any]> in
            guard let resolverEthereumAddress = result["0"] as? EthereumAddress else { return .init(error: AnyError(ENSError(description: "Error extracting result from \(Self.registrarContract).\(function.name)()"))) }
            let resolver = AlphaWallet.Address(address: resolverEthereumAddress)
            guard !resolver.isNull else { return .init(error: AnyError(ENSError(description: "Null address returned"))) }
            let function = ENSReverseLookupEncode()
            return delegate.callSmartContract(withChainId: chainId, contract: resolver, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject])
        }.then { result -> Promise<(String, AlphaWallet.Address)> in
            guard let ensName = result["0"] as? String, ensName.contains(".") else { return .init(error: AnyError(ENSError(description: "Incorrect data output from ENS resolver"))) }
            return self.getENSAddress(fromName: ensName).map { (ensName, $0) }
        }.map { ensName, resolvedAddress -> String in
            if address == resolvedAddress {
                return ensName
            } else {
                throw AnyError(ENSError(description: "Forward resolution of ENS name found by reverse look up doesn't match"))
            }
        }
    }

    public func getTextRecord(forName name: String, recordKey: EnsTextRecordKey) -> Promise<String> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return Promise { _ in } }
        guard !name.components(separatedBy: ".").isEmpty else { return .init(error: AnyError(ENSError(description: "\(name) is invalid ENS name"))) }

        let addr = name.lowercased().nameHash
        let function = GetEnsTextRecord()
        let chainId = chainId
        return firstly {
            delegate.callSmartContract(withChainId: chainId, contract: getENSRecordsContract(forChainId: chainId), functionName: function.name, abiString: function.abi, parameters: [addr as AnyObject, recordKey.rawValue as AnyObject])
        }.then { result -> Promise<String> in
            guard let record = result["0"] as? String else { return .init(error: AnyError(ENSError(description: "interface doesn't support for chainId \(chainId)"))) }
            guard !record.isEmpty else { return .init(error: AnyError(ENSError(description: "ENS text record not found for record: \(record) for chainId: \(chainId)"))) }
            return .value(record)
        }
    }

    private func isSupportEnsIp10(resolver: AlphaWallet.Address) -> Promise<Bool> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return Promise { _ in } }

        let hash = "0x9061b923" //ENSIP-10 resolve(bytes,bytes)"
        return delegate.getInterfaceSupported165(chainId: chainId, hash: hash, contract: resolver)
    }

    private func getResolver(forName name: String) -> Promise<AlphaWallet.Address> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return Promise { _ in } }

        let function = GetENSResolverEncode()
        let chainId = chainId
        let node = name.lowercased().nameHash
        return firstly {
            delegate.callSmartContract(withChainId: chainId, contract: Self.registrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject])
        }.then { result -> Promise<AlphaWallet.Address> in
            if let resolver = (result["0"] as? EthereumAddress).flatMap({ AlphaWallet.Address(address: $0) }) {
                verboseLog("[ENS] fetched resolver: \(resolver) for: \(name) arg: \(node)")
                if resolver.isNull && name != "" {
                    //Wildcard resolution https://docs.ens.domains/ens-improvement-proposals/ensip-10-wildcard-resolution
                    let parentName = name.split(separator: ".").dropFirst().joined(separator: ".")
                    verboseLog("[ENS] fetching parent \(parentName) resolver again for ENSIP-10. Was: \(resolver) for: \(name) arg: \(node)")
                    return self.getResolver(forName: parentName)
                } else {
                    if resolver.isNull {
                        throw AnyError(ENSError(description: "Null address returned"))
                    } else {
                        return .value(resolver)
                    }
                }
            } else {
                throw AnyError(ENSError(description: "Error extracting result from \(Self.registrarContract).\(function.name)()"))
            }
        }
    }

    private func getENSAddressFromResolverUsingAddr(forName name: String, node: String, resolver: AlphaWallet.Address) -> Promise<AlphaWallet.Address> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return Promise { _ in } }

        let function = GetENSRecordWithResolverAddrEncode()
        let chainId = chainId
        verboseLog("[ENS] calling function \(function.name) for name: \(name)…")
        return firstly {
            delegate.callSmartContract(withChainId: chainId, contract: resolver, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject])
        }.map { result in
            guard let ensAddressEthereumAddress = result["0"] as? EthereumAddress else { throw AnyError(ENSError(description: "Incorrect data output from ENS resolver")) }
            let ensAddress = AlphaWallet.Address(address: ensAddressEthereumAddress)
            verboseLog("[ENS] called function \(function.name) for name: \(name) result: \(ensAddress.eip55String)")
            guard !ensAddress.isNull else { throw AnyError(ENSError(description: "Null address returned")) }
            return ensAddress
        }
    }

    private func getENSAddressFromResolverUsingResolve(forName name: String, node: String, resolver: AlphaWallet.Address) -> Promise<AlphaWallet.Address> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return Promise { _ in } }

        let addrFunction = GetENSRecordWithResolverAddrEncode()
        let resolveFunction = GetENSRecordWithResolverResolveEncode()
        let dnsEncodedName = functional.dnsEncode(name: name)
        guard let callData = delegate.getSmartContractCallData(withChainId: chainId, contract: resolver, functionName: addrFunction.name, abiString: addrFunction.abi, parameters: [node] as [AnyObject]) else {
            struct FailedToBuildCallDataForEnsIp10: Error {}
            return Promise(error: FailedToBuildCallDataForEnsIp10())
        }
        verboseLog("[ENS] addr data calldata: \(callData.hexString)")
        let parameters: [AnyObject] = [
            dnsEncodedName as AnyObject,
            callData as AnyObject,
        ]
        let chainId = chainId
        verboseLog("[ENS] calling function \(resolveFunction.name) for name: \(name) DNS-encoded name: \(dnsEncodedName.hex()) callData: \(callData.hex())…")
        return firstly {
            delegate.callSmartContract(withChainId: chainId, contract: resolver, functionName: resolveFunction.name, abiString: resolveFunction.abi, parameters: parameters)
        }.map { result in
            guard let addressStringAsData = result["0"] as? Data else { throw AnyError(ENSError(description: "Incorrect data output from ENS resolver")) }
            let addressStringLeftPaddedWithZeros = addressStringAsData.hexString
            let addressString = String(addressStringLeftPaddedWithZeros.dropFirst(addressStringLeftPaddedWithZeros.count - 40))
            verboseLog("[ENS] called function \(resolveFunction.name) for name: \(name) result: \(addressString)")
            guard let address = AlphaWallet.Address(uncheckedAgainstNullAddress: addressString) else { throw AnyError(ENSError(description: "Incorrect data output from ENS resolver")) }
            guard !address.isNull else { throw AnyError(ENSError(description: "Null address returned")) }
            return address
        }
    }

    private func getENSRecordsContract(forChainId chainId: ChainId) -> AlphaWallet.Address {
        //TODO why POA does use a different one but we use the same ENS registrar contract for all chains?
        if chainId == 99 {
            return AlphaWallet.Address(string: "0xF60cd4F86141D7Fe4A1A9961451Ea09230A14617")!
        } else {
            return AlphaWallet.Address(string: "0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41")!
        }
    }
}

extension ENS {
    class functional {}
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
