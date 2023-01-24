//
//  WalletConnectTransaction.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 01.12.2022.
//
import AlphaWalletCore
import Foundation
import BigInt

public struct WalletConnectTransaction {
    public let value: BigUInt?
    public let to: AlphaWallet.Address?
    public let data: Data
    public let gasLimit: BigUInt?
    public let gasPrice: BigUInt?
    public let nonce: BigUInt?

    public init(value: BigUInt? = nil,
                to: AlphaWallet.Address? = nil,
                data: Data = Data(),
                gasLimit: BigUInt? = nil,
                gasPrice: BigUInt? = nil,
                nonce: BigUInt? = nil) {

        self.value = value
        self.to = to
        self.data = data
        self.gasLimit = gasLimit
        self.gasPrice = gasPrice
        self.nonce = nonce
    }
}

extension WalletConnectTransaction: Decodable {
    private enum CodingKeys: String, CodingKey {
        case from
        case to
        case gas
        case gasLimit
        case gasPrice
        case nonce
        case value
        case data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        to = (try? container.decode(String.self, forKey: .to)).flatMap { AlphaWallet.Address(string: $0) }
        let gasLimit = (try? container.decode(String.self, forKey: .gasLimit)).flatMap { BigUInt($0.drop0x, radix: 16) }
        let gas = (try? container.decode(String.self, forKey: .gas)).flatMap { BigUInt($0.drop0x, radix: 16) }
        self.gasLimit = gasLimit ?? gas
        gasPrice = (try? container.decode(String.self, forKey: .gasPrice)).flatMap { BigUInt($0.drop0x, radix: 16) }
        value = (try? container.decode(String.self, forKey: .value)).flatMap { BigUInt($0.drop0x, radix: 16) } ?? .zero
        nonce = (try? container.decode(String.self, forKey: .nonce)).flatMap { BigUInt($0.drop0x, radix: 16) }
        data = (try? container.decode(String.self, forKey: .data)).flatMap { Data.fromHex($0) } ?? Data()

    }
}
