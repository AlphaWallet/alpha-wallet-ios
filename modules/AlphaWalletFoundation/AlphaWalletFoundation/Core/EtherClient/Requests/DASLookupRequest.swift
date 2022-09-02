//
//  DASLookupRequest.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.10.2021.
//

import JSONRPCKit
import Foundation

struct DASLookupRequest: JSONRPCKit.Request {
    typealias Response = DASLookupResponse

    let value: String

    var method: String {
        return "das_searchAccount"
    }

    var parameters: Any? {
        return [value]
    }

    func response(from resultObject: Any) throws -> Response {
        guard let data = try? JSONSerialization.data(withJSONObject: resultObject, options: []) else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
        if let data = try? JSONDecoder().decode(DASLookupResponse.self, from: data) {
            return data
        } else {
            throw CastError(actualValue: resultObject, expectedType: Response.self)
        }
    }
}

struct DASLookupResponse: Decodable {
    enum CodingKeys: String, CodingKey {
        case errno, errmsg, data
    }
    let errno: Int
    let errmsg: String
    let records: [Record]
    let ownerAddress: AlphaWallet.Address?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        errno = try container.decode(Int.self, forKey: .errno)
        errmsg = try container.decode(String.self, forKey: .errmsg)
        if let value = try? container.decodeIfPresent(DataClass.self, forKey: .data) {
            records = value?.accountData.records ?? []
            if value?.accountData.ownerAddressChain == "ETH", let address = value?.accountData.ownerAddress {
                ownerAddress = AlphaWallet.Address(string: address)
            } else {
                ownerAddress = nil
            }
        } else {
            records = []
            ownerAddress = nil
        }
    }

    struct DataClass: Decodable {
        let accountData: AccountData
        enum CodingKeys: String, CodingKey {
            case accountData = "account_data"
        }
    }

    struct AccountData: Decodable {
        enum CodingKeys: String, CodingKey {
            case records
            case ownerAddressChain = "owner_address_chain"
            case ownerAddress = "owner_address"
        }
        let records: [Record]
        let ownerAddressChain: String?
        let ownerAddress: String?
    }

    struct Record: Decodable {
        enum CodingKeys: String, CodingKey {
            case key, label, value, ttl
        }
        let key: String
        let label: String
        let value: String
        let ttl: String
    }
}