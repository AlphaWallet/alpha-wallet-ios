//
//  UnstoppableDomainsV2Resolver.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 27.01.2022.
//

import Foundation
import PromiseKit
import Alamofire
import SwiftyJSON
import AlphaWalletENS

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

    func resolveAddress(forName name: String) -> Promise<AlphaWallet.Address> {
        if let value = AlphaWallet.Address(string: name) {
            return .value(value)
        }

        if let value = cachedAddressValue(for: name) {
            return .value(value)
        }

        let baseURL = Constants.unstoppableDomainsV2API
        guard let url = URL(string: "\(baseURL)/domains/\(name)") else {
            return .init(error: UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)"))
        }

        verboseLog("[UnstoppableDomains] resolving name: \(name)…")
        return Alamofire
            .request(url, method: .get, headers: ["Authorization": Constants.Credentials.unstoppableDomainsV2ApiKey])
            .responseJSON(queue: .main, options: .allowFragments).map { response -> AlphaWallet.Address in
                guard let data = response.response.data, let json = try? JSON(data: data) else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                }

                let value = try AddressResolution.Response(json: json)
                if let owner = value.meta.owner {
                    verboseLog("[UnstoppableDomains] resolved name: \(name) result: \(owner.eip55String)")
                    return owner
                } else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                }
            }.get { address in
                let key = EnsLookupKey(nameOrAddress: name, server: self.server)
                self.storage.addOrUpdate(record: .init(key: key, value: .address(address)))
            }
    }

    func resolveDomain(address: AlphaWallet.Address) -> Promise<String> {
        if let value = cachedEnsValue(for: address) {
            return .value(value)
        }

        let baseURL = Constants.unstoppableDomainsV2API
        guard let url = URL(string: "\(baseURL)/domains/?owners=\(address.eip55String)&sortBy=id&sortDirection=DESC&perPage=50") else {
            return .init(error: UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)"))
        }

        verboseLog("[UnstoppableDomains] resolving address: \(address.eip55String)…")
        return Alamofire
            .request(url, method: .get, headers: ["Authorization": Constants.Credentials.unstoppableDomainsV2ApiKey])
            .responseJSON(queue: .main, options: .allowFragments).map { response -> String in
                guard let data = response.response.data, let json = try? JSON(data: data) else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                }

                let value = try DomainResolution.Response(json: json)
                if let record = value.data.first {
                    verboseLog("[UnstoppableDomains] resolved address: \(address.eip55String) result: \(record.id)")
                    return record.id
                } else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                }
            }.get { domain in
                let key = EnsLookupKey(nameOrAddress: address.eip55String, server: self.server)
                self.storage.addOrUpdate(record: .init(key: key, value: .ens(domain)))
            }
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
