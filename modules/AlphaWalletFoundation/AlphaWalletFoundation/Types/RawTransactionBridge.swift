//
//  RawTransactionBridge.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 01.12.2022.
//
import AlphaWalletCore
import Foundation
import BigInt

public struct RawTransactionBridge {
    public var value: BigUInt? = .none
    public var to: AlphaWallet.Address? = .none
    public var data: Data? = .none
    public var gas: BigUInt? = .none
    public var gasPrice: BigUInt? = .none
    public var nonce: BigUInt? = .none

    public init(value: BigUInt? = .none, to: AlphaWallet.Address? = .none, data: Data? = .none, gas: BigUInt? = .none, gasPrice: BigUInt? = .none, nonce: BigUInt? = .none) {
        self.value = value
        self.to = to
        self.data = data
        self.gas = gas
        self.gasPrice = gasPrice
        self.nonce = nonce
    }
}

extension RawTransactionBridge: Decodable {
    private enum CodingKeys: String, CodingKey {
        case from
        case to
        case gas
        case gasPrice
        case nonce
        case value
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let value = try? container.decode(String.self, forKey: .to) {
            to = AlphaWallet.Address(string: value)
        }
        if let value = try? container.decode(String.self, forKey: .gas).drop0x {
            gas = BigUInt(value, radix: 16)
        }
        if let value = try? container.decode(String.self, forKey: .gasPrice).drop0x {
            gasPrice = BigUInt(value, radix: 16)
        }
        if let _value = try? container.decode(String.self, forKey: .value).drop0x {
            value = BigUInt(_value, radix: 16)
        }
        if let value = try? container.decode(String.self, forKey: .nonce).drop0x {
            nonce = BigUInt(value, radix: 16)
        }
        if let value = try? container.decode(String.self, forKey: .data).drop0x {
            data = Data.fromHex(value)
        }
    }
}
