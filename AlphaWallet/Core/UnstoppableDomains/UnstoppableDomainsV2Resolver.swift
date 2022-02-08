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

struct UnstoppableDomainsV2ApiError: Error {
    var localizedDescription: String
}

class UnstoppableDomainsV2Resolver {
    private let server: RPCServer
    private static var addressesCache: [ENSLookupKey: AlphaWallet.Address] = [:]
    private static var domainsCache: [ENSLookupKey: String] = [:]

    init(server: RPCServer) {
        self.server = server
    }

    private static func cachedAddress(forNode node: String, server: RPCServer) -> AlphaWallet.Address? {
        return UnstoppableDomainsV2Resolver.addressesCache[ENSLookupKey(name: node, server: server)]
    }

    private static func cache(forNode node: String, address: AlphaWallet.Address, server: RPCServer) {
        UnstoppableDomainsV2Resolver.addressesCache[ENSLookupKey(name: node, server: server)] = address
    }

    private static func cachedDomain(forNode node: String, server: RPCServer) -> String? {
        return UnstoppableDomainsV2Resolver.domainsCache[ENSLookupKey(name: node, server: server)]
    }

    private static func cache(forNode node: String, domain: String, server: RPCServer) {
        UnstoppableDomainsV2Resolver.domainsCache[ENSLookupKey(name: node, server: server)] = domain
    }

    func resolveAddress(for input: String) -> Promise<AlphaWallet.Address> {
        if let value = AlphaWallet.Address(string: input) {
            return .value(value)
        }

        let server = server
        let node = input.lowercased().nameHash
        if let value = UnstoppableDomainsV2Resolver.cachedAddress(forNode: node, server: server) {
            return .value(value)
        }

        let baseURL = Constants.unstoppableDomainsV2API
        guard let url = URL(string: "\(baseURL)/domains/\(input)") else {
            return .init(error: UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)"))
        }

        return Alamofire
            .request(url, method: .get, headers: ["Authorization": Constants.Credentials.unstoppableDomainsV2ApiKey])
            .responseJSON(queue: .main, options: .allowFragments).map { response -> AlphaWallet.Address in
                guard let data = response.response.data, let json = try? JSON(data: data) else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                }

                let value = try AddressResolution.Response(json: json)
                if let owner = value.meta.owner {
                    return owner
                } else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                }
            }.get { address in
                UnstoppableDomainsV2Resolver.cache(forNode: node, address: address, server: server)
            }
    }

    func resolveDomain(address: AlphaWallet.Address) -> Promise<String> {
        let server = server
        let node = address.eip55String
        if let value = UnstoppableDomainsV2Resolver.cachedDomain(forNode: node, server: server) {
            return .value(value)
        }

        let baseURL = Constants.unstoppableDomainsV2API
        guard let url = URL(string: "\(baseURL)/domains/?owners=\(address.eip55String)&sortBy=id&sortDirection=DESC&perPage=50") else {
            return .init(error: UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)"))
        }

        return Alamofire
            .request(url, method: .get, headers: ["Authorization": Constants.Credentials.unstoppableDomainsV2ApiKey])
            .responseJSON(queue: .main, options: .allowFragments).map { response -> String in
                guard let data = response.response.data, let json = try? JSON(data: data) else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                }

                let value = try DomainResolution.Response(json: json)
                if let record = value.data.first {
                    return record.id
                } else {
                    throw UnstoppableDomainsV2ApiError(localizedDescription: "Error calling \(baseURL) API isMainThread: \(Thread.isMainThread)")
                }
            }.get { domain in
                UnstoppableDomainsV2Resolver.cache(forNode: node, domain: domain, server: server)
            }
    }
}

extension UnstoppableDomainsV2Resolver: CachebleAddressResolutionServiceType {

    func cachedAddressValue(for input: String) -> AlphaWallet.Address? {
        return UnstoppableDomainsV2Resolver.cachedAddress(forNode: input.lowercased().nameHash, server: server)
    }
}

extension UnstoppableDomainsV2Resolver: CachedEnsResolutionServiceType {

    func cachedEnsValue(for address: AlphaWallet.Address) -> String? {
        return UnstoppableDomainsV2Resolver.cachedDomain(forNode: address.eip55String, server: server)
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
