//
// Created by James Sangalli on 8/11/18.
//
import Foundation
import CryptoSwift
import Result
import web3swift

//https://github.com/ethereum/EIPs/blob/master/EIPS/eip-137.md
extension String {
    var nameHash: String {
        var node = Array<UInt8>.init(repeating: 0x0, count: 32)
        if !self.isEmpty {
            node = self.split(separator: ".")
                .map { Array($0.utf8).sha3(.keccak256) }
                .reversed()
                .reduce(node) { return ($0 + $1).sha3(.keccak256) }
        }
        return "0x" + node.toHexString()
    }
}

class GetENSAddressCoordinator {
    private struct ENSLookupKey: Hashable {
        let name: String
        let server: RPCServer
    }

    private static var resultsCache = [ENSLookupKey:EthereumAddress]()
    private static let DELAY_AFTER_STOP_TYPING_TO_START_RESOLVING_ENS_NAME = TimeInterval(0.5)

    private var toStartResolvingEnsNameTimer: Timer?
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func getENSAddressFromResolver(
            for input: String,
            completion: @escaping (Result<EthereumAddress, AnyError>) -> Void
    ) {

        //if already an address, send back the address
        if let ethAddress = EthereumAddress(input) {
            completion(.success(ethAddress))
            return
        }

        //if it does not contain .eth, then it is not a valid ens name
        if !input.contains(".") {
            completion(.failure(AnyError(Web3Error(description: "Invalid ENS Name"))))
            return
        }

        let node = input.lowercased().nameHash
        if let cachedResult = cachedResult(forNode: node) {
            completion(.success(cachedResult))
            return
        }

        let function = GetENSResolverEncode()
        callSmartContract(withServer: server, contract: server.ensRegistrarContract, functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).done { result in
            //if null address is returned (as 0) we count it as invalid
            //this is because it is not assigned to an ENS and puts the user in danger of sending funds to null
            if let resolver = result["0"] as? EthereumAddress {
                if Constants.nullAddress.sameContract(as: resolver) {
                    completion(.failure(AnyError(Web3Error(description: "Null address returned"))))
                } else {
                    let function = GetENSRecordFromResolverEncode()
                    callSmartContract(withServer: self.server, contract: AlphaWallet.Address(address: resolver), functionName: function.name, abiString: function.abi, parameters: [node] as [AnyObject]).done { result in
                        if let ensAddress = result["0"] as? EthereumAddress {
                            if Constants.nullAddress.sameContract(as: ensAddress) {
                                completion(.failure(AnyError(Web3Error(description: "Null address returned"))))
                            } else {
                                //Retain self because it's useful to cache the results even if we don't immediately need it now
                                self.cache(forNode: node, result: ensAddress)
                                completion(.success(ensAddress))
                            }
                        } else {
                            completion(.failure(AnyError(Web3Error(description: "Incorrect data output from ENS resolver"))))
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

    func queueGetENSOwner(for input: String, completion: @escaping (Result<EthereumAddress, AnyError>) -> Void) {
        let node = input.lowercased().nameHash
        if let cachedResult = cachedResult(forNode: node) {
            completion(.success(cachedResult))
            return
        }

        toStartResolvingEnsNameTimer?.invalidate()
        toStartResolvingEnsNameTimer = Timer.scheduledTimer(withTimeInterval: GetENSAddressCoordinator.DELAY_AFTER_STOP_TYPING_TO_START_RESOLVING_ENS_NAME, repeats: false) { _ in
            //Retain self because it's useful to cache the results even if we don't immediately need it now
            self.getENSAddressFromResolver(for: input) { result in
                completion(result)
            }
        }
    }

    private func cachedResult(forNode node: String) -> EthereumAddress? {
        return GetENSAddressCoordinator.resultsCache[ENSLookupKey(name: node, server: server)]
    }

    private func cache(forNode node: String, result: EthereumAddress) {
        GetENSAddressCoordinator.resultsCache[ENSLookupKey(name: node, server: server)] = result
    }
}
