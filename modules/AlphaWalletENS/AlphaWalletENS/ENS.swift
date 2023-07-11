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

public typealias ChainId = Int

public enum SmartContractError: Error {
    case delegateNotFound
    case embedded(Error)
}

public protocol ENSDelegate: AnyObject {
    func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> AnyPublisher<[String: Any], SmartContractError>
    func getSmartContractCallData(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject]) -> Data?
    func getInterfaceSupported165(chainId: Int, hash: String, contract: AlphaWallet.Address) -> AnyPublisher<Bool, SmartContractError>
}

extension ENSDelegate {
    func callSmartContract(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = []) -> AnyPublisher<[String: Any], SmartContractError> {
        callSmartContract(withChainId: chainId, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters)
    }

    func getSmartContractCallData(withChainId chainId: ChainId, contract: AlphaWallet.Address, functionName: String, abiString: String, parameters: [AnyObject] = []) -> Data? {
        getSmartContractCallData(withChainId: chainId, contract: contract, functionName: functionName, abiString: abiString, parameters: parameters)
    }
}

public class ENS {
    //Always Ethereum mainnet's. For now at least
    private static let registrarContract = AlphaWallet.Address(string: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e")!

    public static var isLoggingEnabled = false

    private weak var delegate: ENSDelegate?
    private let chainId: ChainId

    public init(delegate: ENSDelegate, chainId: ChainId) {
        self.delegate = delegate
        self.chainId = chainId
    }

    public func getENSAddress(fromName name: String) -> AnyPublisher<AlphaWallet.Address, SmartContractError> {
        //if already an address, send back the address
        if let ethAddress = AlphaWallet.Address(string: name) { return .just(ethAddress) }

        //if it does not contain .eth, then it is not a valid ens name
        if !name.contains(".") {
            return .fail(.embedded(ENSError(description: "Invalid ENS Name")))
        }

        return getResolver(forName: name)
            .flatMap { resolver -> AnyPublisher<(AlphaWallet.Address, Bool), SmartContractError> in
                self.isSupportEnsIp10(resolver: resolver).map { (resolver, $0) }.eraseToAnyPublisher()
            }.flatMap { resolver, supportsEnsIp10 -> AnyPublisher<AlphaWallet.Address, SmartContractError> in
                verboseLog("[ENS] Fetch resolver: \(resolver.eip55String) supports ENSIP-10? \(supportsEnsIp10) for name: \(name)")
                let node = name.lowercased().nameHash
                if supportsEnsIp10 {
                    return self.getENSAddressFromResolverUsingResolve(forName: name, node: node, resolver: resolver)
                } else {
                    return self.getENSAddressFromResolverUsingAddr(forName: name, node: node, resolver: resolver)
                }
            }.eraseToAnyPublisher()
    }

    //Performs a ENS reverse lookup — figure out ENS name from a given Ethereum address — and then forward resolves the ENS name (look up Ethereum address from ENS name) to verify it. This is necessary because:
    // (quoted from https://docs.ens.domains/dapp-developer-guide/resolving-names)
    // > "ENS does not enforce the accuracy of reverse records - for instance, anyone may claim that the name for their address is 'alice.eth'. To be certain that the claim is accurate, you must always perform a forward resolution for the returned name and check it matches the original address."
    public func getName(fromAddress address: AlphaWallet.Address) -> AnyPublisher<String, SmartContractError> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return .fail(SmartContractError.delegateNotFound) }

        let node = address.nameHash
        let function = GetENSResolverEncode()
        let chainId = chainId
        return delegate.callSmartContract(withChainId: chainId, contract: Self.registrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).flatMap { result -> AnyPublisher<[String: Any], SmartContractError> in
            guard let resolverEthereumAddress = result["0"] as? EthereumAddress else {
                let error = ENSError(description: "Error extracting result from \(Self.registrarContract).\(function.name)()")
                return .fail(.embedded(error))
            }
            let resolver = AlphaWallet.Address(address: resolverEthereumAddress)
            guard !resolver.isNull else {
                let error = ENSError(description: "Null address returned")
                return .fail(.embedded(error))
            }
            let function = ENSReverseLookupEncode()
            return delegate.callSmartContract(withChainId: chainId, contract: resolver, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject])
        }.flatMap { result -> AnyPublisher<(String, AlphaWallet.Address), SmartContractError> in
            guard let ensName = result["0"] as? String, ensName.contains(".") else {
                let error = ENSError(description: "Incorrect data output from ENS resolver")
                return .fail(.embedded(error))
            }
            return self.getENSAddress(fromName: ensName).map { (ensName, $0) }.eraseToAnyPublisher()
        }.tryMap { ensName, resolvedAddress -> String in
            if address == resolvedAddress {
                return ensName
            } else {
                throw ENSError(description: "Forward resolution of ENS name found by reverse look up doesn't match")
            }
        }.mapError { e in
            SmartContractError.embedded(e)
        }.eraseToAnyPublisher()
    }

    public func getTextRecord(forName name: String, recordKey: EnsTextRecordKey) -> AnyPublisher<String, SmartContractError> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return .fail(.delegateNotFound) }
        guard !name.components(separatedBy: ".").isEmpty else {
            return .fail(.embedded(ENSError(description: "\(name) is invalid ENS name")))
        }

        let addr = name.lowercased().nameHash
        let function = GetEnsTextRecord()
        let chainId = chainId
        return delegate.callSmartContract(withChainId: chainId, contract: getENSRecordsContract(forChainId: chainId), functionName: function.name, abiString: function.abi, parameters: [addr as AnyObject, recordKey.rawValue as AnyObject]).tryMap { result -> String in
            guard let record = result["0"] as? String else { throw ENSError(description: "interface doesn't support for chainId \(chainId)") }
            guard !record.isEmpty else { throw ENSError(description: "ENS text record not found for record: \(record) for chainId: \(chainId)") }
            return record
        }.mapError { e in
            SmartContractError.embedded(e)
        }.eraseToAnyPublisher()
    }

    private func isSupportEnsIp10(resolver: AlphaWallet.Address) -> AnyPublisher<Bool, SmartContractError> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return .fail(.delegateNotFound) }

        let hash = "0x9061b923" //ENSIP-10 resolve(bytes,bytes)"
        return delegate.getInterfaceSupported165(chainId: chainId, hash: hash, contract: resolver)
    }

    private func getResolver(forName name: String) -> AnyPublisher<AlphaWallet.Address, SmartContractError> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return .fail(.delegateNotFound) }

        let function = GetENSResolverEncode()
        let chainId = chainId
        let node = name.lowercased().nameHash
        return delegate.callSmartContract(withChainId: chainId, contract: Self.registrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).flatMap { result -> AnyPublisher<AlphaWallet.Address, SmartContractError> in
            if let resolver = (result["0"] as? EthereumAddress).flatMap({ AlphaWallet.Address(address: $0) }) {
                verboseLog("[ENS] fetched resolver: \(resolver) for: \(name) arg: \(node)")
                if resolver.isNull && name != "" {
                    //Wildcard resolution https://docs.ens.domains/ens-improvement-proposals/ensip-10-wildcard-resolution
                    let parentName = name.split(separator: ".").dropFirst().joined(separator: ".")
                    verboseLog("[ENS] fetching parent \(parentName) resolver again for ENSIP-10. Was: \(resolver) for: \(name) arg: \(node)")
                    return self.getResolver(forName: parentName)
                } else {
                    if resolver.isNull {
                        let error = ENSError(description: "Null address returned")
                        return .fail(.embedded(error))
                    } else {
                        return .just(resolver)
                    }
                }
            } else {
                let error = ENSError(description: "Error extracting result from \(Self.registrarContract).\(function.name)()")
                return .fail(.embedded(error))
            }
        }.eraseToAnyPublisher()
    }

    private func getENSAddressFromResolverUsingAddr(forName name: String, node: String, resolver: AlphaWallet.Address) -> AnyPublisher<AlphaWallet.Address, SmartContractError> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return .fail(.delegateNotFound) }

        let function = GetENSRecordWithResolverAddrEncode()
        let chainId = chainId
        verboseLog("[ENS] calling function \(function.name) for name: \(name)…")
        return delegate.callSmartContract(withChainId: chainId, contract: resolver, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).tryMap { result in
            guard let ensAddressEthereumAddress = result["0"] as? EthereumAddress else { throw ENSError(description: "Incorrect data output from ENS resolver") }
            let ensAddress = AlphaWallet.Address(address: ensAddressEthereumAddress)
            verboseLog("[ENS] called function \(function.name) for name: \(name) result: \(ensAddress.eip55String)")
            guard !ensAddress.isNull else { throw ENSError(description: "Null address returned") }
            return ensAddress
        }.mapError { e in
            SmartContractError.embedded(e)
        }.eraseToAnyPublisher()
    }

    private func getENSAddressFromResolverUsingResolve(forName name: String, node: String, resolver: AlphaWallet.Address) -> AnyPublisher<AlphaWallet.Address, SmartContractError> {
        //TODO improve if delegate is nil
        guard let delegate = delegate else { return .fail(.delegateNotFound) }

        let addrFunction = GetENSRecordWithResolverAddrEncode()
        let resolveFunction = GetENSRecordWithResolverResolveEncode()
        let dnsEncodedName = functional.dnsEncode(name: name)
        guard let callData = delegate.getSmartContractCallData(withChainId: chainId, contract: resolver, functionName: addrFunction.name, abiString: addrFunction.abi, parameters: [node] as [AnyObject]) else {
            struct FailedToBuildCallDataForEnsIp10: Error {}
            return Fail(error: SmartContractError.embedded(FailedToBuildCallDataForEnsIp10()))
                .eraseToAnyPublisher()
        }
        verboseLog("[ENS] addr data calldata: \(callData.hexString)")
        let parameters: [AnyObject] = [
            dnsEncodedName as AnyObject,
            callData as AnyObject,
        ]
        let chainId = chainId
        verboseLog("[ENS] calling function \(resolveFunction.name) for name: \(name) DNS-encoded name: \(dnsEncodedName.hex()) callData: \(callData.hex())…")
        return delegate.callSmartContract(withChainId: chainId, contract: resolver, functionName: resolveFunction.name, abiString: resolveFunction.abi, parameters: parameters).tryMap { result in
            guard let addressStringAsData = result["0"] as? Data else { throw ENSError(description: "Incorrect data output from ENS resolver") }
            let addressStringLeftPaddedWithZeros = addressStringAsData.hexString
            let addressString = String(addressStringLeftPaddedWithZeros.dropFirst(addressStringLeftPaddedWithZeros.count - 40))
            verboseLog("[ENS] called function \(resolveFunction.name) for name: \(name) result: \(addressString)")
            guard let address = AlphaWallet.Address(uncheckedAgainstNullAddress: addressString) else { throw ENSError(description: "Incorrect data output from ENS resolver") }
            guard !address.isNull else { throw ENSError(description: "Null address returned") }
            return address
        }.mapError { e in
            SmartContractError.embedded(e)
        }.eraseToAnyPublisher()
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
