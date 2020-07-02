//
//  RawTransactionBridge.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.10.2020.
//

import Foundation
import BigInt

struct RawTransactionBridge: Decodable {
    private enum CodingKeys: String, CodingKey {
        case from
        case to
        case gas
        case gasPrice
        case nonce
        case value
        case data
    }

    var value: BigInt? = .none
    var to: AlphaWallet.Address? = .none
    var data: Data? = .none
    var gas: BigInt? = .none
    var gasPrice: BigInt? = .none
    var nonce: BigInt? = .none

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode(String.self, forKey: .to) {
            to = AlphaWallet.Address(string: value)
        }
        if let value = try? container.decode(String.self, forKey: .gas).drop0x {
            gas = BigInt(value, radix: 16)
        }
        if let value = try? container.decode(String.self, forKey: .gasPrice).drop0x {
            gasPrice = BigInt(value, radix: 16)
        }
        if let _value = try? container.decode(String.self, forKey: .value).drop0x {
            value = BigInt(_value, radix: 16)
        }
        if let value = try? container.decode(String.self, forKey: .nonce).drop0x {
            nonce = BigInt(value, radix: 16)
        }
        if let value = try? container.decode(String.self, forKey: .data).drop0x {
            data = Data.fromHex(value)
        }
    }
}
