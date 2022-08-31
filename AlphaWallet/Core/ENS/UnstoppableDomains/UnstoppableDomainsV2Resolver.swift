//
//  UnstoppableDomainsV2Resolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import Combine
import Alamofire
import SwiftyJSON
import AlphaWalletENS
import AlphaWalletCore

struct UnstoppableDomainsV2ApiError: Error {
    var localizedDescription: String
}

class UnstoppableDomainsV2Resolver {
    private let server: RPCServer
    private let storage: EnsRecordsStorage

    init(server: RPCServer, storage: EnsRecordsStorage) {
        self.server = server
        self.storage = storage
    }

    func resolveAddress(forName name: String) -> AnyPublisher<AlphaWallet.Address, PromiseError> {
        if let value = AlphaWallet.Address(string: name) {
            return .just(value)
        }

        if let value = self.cachedAddressValue(for: name) {
            return .just(value)
        }

        let baseURL = Constants.unstoppableDomainsV2API
        guard let url = URL(string: "\(baseURL)/domains/\(name)") else {
            let error = UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")

            return .fail(.some(error: error))
        }

        return Just(name)
            .setFailureType(to: PromiseError.self)
            .flatMap { name -> AnyPublisher<AlphaWallet.Address, PromiseError> in
                infoLog("[UnstoppableDomains] resolving name: \(name)…")
                return Alamofire
                    .request(url, method: .get, headers: ["Authorization": Constants.Credentials.unstoppableDomainsV2ApiKey])
                    .responseDataPublisher().tryMap { response -> AlphaWallet.Address in
                        guard let data = response.response.data, let json = try? JSON(data: data) else {
                            throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                        }

                        let value = try AddressResolution.Response(json: json)
                        if let owner = value.meta.owner {
                            infoLog("[UnstoppableDomains] resolved name: \(name) result: \(owner.eip55String)")
                            return owner
                        } else {
                            throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                        }
                    }.handleEvents(receiveOutput: { address in
                        let key = EnsLookupKey(nameOrAddress: name, server: self.server)
                        self.storage.addOrUpdate(record: .init(key: key, value: .address(address)))
                    }).mapError { PromiseError.some(error: $0) }
                    .share()
                    .eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    func resolveDomain(address: AlphaWallet.Address) -> AnyPublisher<String, PromiseError> {
        if let value = self.cachedEnsValue(for: address) {
            return .just(value)
        }

        let baseURL = Constants.unstoppableDomainsV2API
        guard let url = URL(string: "\(baseURL)/domains/?owners=\(address.eip55String)&sortBy=id&sortDirection=DESC&perPage=50") else {
            let error = UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")

            return .fail(.some(error: error))
        }

        return Just(address)
            .setFailureType(to: PromiseError.self)
            .flatMap { address -> AnyPublisher<String, PromiseError> in
                infoLog("[UnstoppableDomains] resolving address: \(address.eip55String)…")
                return Alamofire
                    .request(url, method: .get, headers: ["Authorization": Constants.Credentials.unstoppableDomainsV2ApiKey])
                    .responseDataPublisher().tryMap { response -> String in
                        guard let data = response.response.data, let json = try? JSON(data: data) else {
                            throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                        }

                        let value = try DomainResolution.Response(json: json)
                        if let record = value.data.first {
                            infoLog("[UnstoppableDomains] resolved address: \(address.eip55String) result: \(record.id)")
                            return record.id
                        } else {
                            throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                        }
                    }.handleEvents(receiveOutput: { domain in
                        let key = EnsLookupKey(nameOrAddress: address.eip55String, server: self.server)
                        self.storage.addOrUpdate(record: .init(key: key, value: .ens(domain)))
                    }).mapError { PromiseError.some(error: $0) }
                    .share()
                    .eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }
}

extension UnstoppableDomainsV2Resolver: CachebleAddressResolutionServiceType {

    func cachedAddressValue(for name: String) -> AlphaWallet.Address? {
        let key = EnsLookupKey(nameOrAddress: name, server: server)
        switch storage.record(for: key, expirationTime: Constants.Ens.recordExpiration)?.value {
        case .address(let address):
            return address
        case .record, .ens, .none:
            return nil
        }
    }
}

extension UnstoppableDomainsV2Resolver: CachedEnsResolutionServiceType {

    func cachedEnsValue(for address: AlphaWallet.Address) -> String? {
        let key = EnsLookupKey(nameOrAddress: address.eip55String, server: server)
        switch storage.record(for: key, expirationTime: Constants.Ens.recordExpiration)?.value {
        case .ens(let ens):
            return ens
        case .record, .address, .none:
            return nil
        }
    }
}

extension UnstoppableDomainsV2Resolver {

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

    struct DomainResolution {
        struct Response {
            struct Pagination {
                let perPage: Int
                let nextStartingAfter: String?
                let sortBy: String
                let sortDirection: String
                let hasMore: Bool

                init(json: JSON) {
                    perPage = json["perPage"].intValue
                    nextStartingAfter = json["nextStartingAfter"].string
                    sortBy = json["sortBy"].stringValue
                    sortDirection = json["sortDirection"].stringValue
                    hasMore = json["hasMore"].boolValue
                }
            }

            struct ResponseData {
                struct Attributes {
                    let meta: AddressResolution.Meta

                    init(json: JSON) throws {
                        meta = try AddressResolution.Meta(json: json["meta"])
                    }
                }

                struct Records {
                    let values: [String: String]

                    init(json: JSON) throws {
                        var values: [String: String] = [:]
                        for key in Constants.unstoppableDomainsRecordKeys {
                            guard let value = json[key].string else { continue }
                            values[key] = value
                        }

                        self.values = values
                    }
                }

                let id: String
                let attributes: Attributes
                let records: Records

                init(json: JSON) throws {
                    guard let id = json["id"].string else {
                        throw DecodingError.idNotFound
                    }
                    self.id = id
                    attributes = try Attributes(json: json["attributes"])
                    records = try Records(json: json["records"])
                }
            }

            let data: [ResponseData]
            let meta: Pagination

            init(json: JSON) throws {
                data = json["data"].arrayValue.compactMap { json in
                    try? ResponseData(json: json)
                }
                meta = Pagination(json: json["meta"])
            }
        }
    }
}
