//
//  UnstoppableDomainsResolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletENS
import AlphaWalletLogger
import AlphaWalletWeb3
import SwiftyJSON

struct UnstoppableDomainsApiError: Error {
    var localizedDescription: String
}

class UnstoppableDomainsResolver {
    private let fallbackServer: RPCServer
    private let storage: DomainNameRecordsStorage
    private let networkProvider: UnstoppableDomainsNetworkProvider

    init(fallbackServer: RPCServer, storage: DomainNameRecordsStorage, networkService: NetworkService) {
        self.fallbackServer = fallbackServer
        self.storage = storage
        self.networkProvider = .init(networkService: networkService)
    }

    func resolveDomain(address: AlphaWallet.Address, server actualServer: RPCServer) async throws -> String {
        do {
            return try await _resolveDomain(address: address, server: actualServer)
        } catch {
            if actualServer == fallbackServer {
                throw error
            } else {
                return try await _resolveDomain(address: address, server: fallbackServer)
            }
        }
    }

    private func _resolveDomain(address: AlphaWallet.Address, server: RPCServer) async throws -> String {
        if let cachedResult = await cachedDomainName(for: address) {
            return cachedResult
        }

        let parameters = [EthereumAddress(address: address)] as [AnyObject]
        let abiString = """
                        [ 
                          { 
                            "constant": false, 
                            "inputs": [ 
                              {"address": "","type": "address"}, 
                            ], 
                            "name": "reverseNameOf", 
                            "outputs": [{"name": "", "type": "string"}], 
                            "type": "function" 
                          },
                        ]
                        """
        do {
            let result = try await callSmartContractAsync(withServer: server, contract: AlphaWallet.Address(string: "0xa9a6A3626993D487d2Dbda3173cf58cA1a9D9e9f")!, functionName: "reverseNameOf", abiString: abiString, parameters: parameters)
            if let name = result["0"] as? String, !name.isEmpty {
                return name
            } else {
                throw UnstoppableDomainsApiError(localizedDescription: "Can't reverse resolve \(address.eip55String) on: \(server)")
            }
        } catch {
            throw UnstoppableDomainsApiError(localizedDescription: "Can't reverse resolve \(address.eip55String) on: \(server)")
        }
    }

    func resolveAddress(forName name: String) async throws -> AlphaWallet.Address {
        if let value = AlphaWallet.Address(string: name) {
            return value
        }

        if let value = await self.cachedAddress(for: name) {
            return value
        }

        infoLog("[UnstoppableDomains] resolving name: \(name)…")
        let address = try await networkProvider.resolveAddress(forName: name)
        let key = DomainNameLookupKey(nameOrAddress: name, server: self.fallbackServer)
        await self.storage.addOrUpdate(record: .init(key: key, value: .address(address)))
        return address
    }
}

extension UnstoppableDomainsResolver: CachedDomainNameReverseResolutionServiceType {
    func cachedDomainName(for address: AlphaWallet.Address) async -> String? {
        let key = DomainNameLookupKey(nameOrAddress: address.eip55String, server: fallbackServer)
        switch await storage.record(for: key, expirationTime: Constants.DomainName.recordExpiration)?.value {
        case .domainName(let domainName):
            return domainName
        case .record, .address, .none:
            return nil
        }
    }
}

extension UnstoppableDomainsResolver: CachedDomainNameResolutionServiceType {
    func cachedAddress(for name: String) async -> AlphaWallet.Address? {
        let key = DomainNameLookupKey(nameOrAddress: name, server: fallbackServer)
        switch await storage.record(for: key, expirationTime: Constants.DomainName.recordExpiration)?.value {
        case .address(let address):
            return address
        case .record, .domainName, .none:
            return nil
        }
    }
}

extension UnstoppableDomainsResolver {
    enum DecodingError: Error {
        case domainNotFound
        case ownerNotFound
        case idNotFound
        case errorMessageNotFound
        case errorCodeNotFound
    }

    struct AddressResolution {
        struct Meta {
            let networkId: Int?
            let domain: String
            let owner: AlphaWallet.Address?
            let blockchain: String?
            let registry: String?

            init(json: JSON) throws {
                guard let domain = json["domain"].string else {
                    throw DecodingError.domainNotFound
                }
                self.domain = domain
                self.owner = json["owner"].string.flatMap { value in
                    AlphaWallet.Address(uncheckedAgainstNullAddress: value)
                }
                networkId = json["networkId"].int
                blockchain = json["blockchain"].string
                registry = json["registry"].string
            }
        }

        struct Response {
            let meta: Meta

            init(json: JSON) throws {
                meta = try Meta(json: json["meta"])
            }
        }
    }
}