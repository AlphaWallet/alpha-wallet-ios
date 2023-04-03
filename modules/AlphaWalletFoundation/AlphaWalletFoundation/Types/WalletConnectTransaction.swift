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
    public let value: BigUInt
    public let recipient: AlphaWallet.Address?
    public let contract: AlphaWallet.Address?
    public let data: Data
    public let gasLimit: BigUInt?
    public let gasPrice: GasPrice?
    public let nonce: BigUInt?

    public init(value: BigUInt = .zero,
                recipient: AlphaWallet.Address? = nil,
                contract: AlphaWallet.Address? = nil,
                data: Data = Data(),
                gasLimit: BigUInt? = nil,
                gasPrice: GasPrice? = nil,
                nonce: BigUInt? = nil) {

        self.contract = contract
        self.value = value
        self.recipient = recipient
        self.data = data
        self.gasLimit = gasLimit
        self.gasPrice = gasPrice
        self.nonce = nonce
    }
}

extension WalletConnectTransaction: Decodable {
    private enum CodingKeys: String, CodingKey {
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

        let gasLimit = (try? container.decode(String.self, forKey: .gasLimit)).flatMap { BigUInt($0.drop0x, radix: 16) }
        let gas = (try? container.decode(String.self, forKey: .gas)).flatMap { BigUInt($0.drop0x, radix: 16) }
        self.gasLimit = gasLimit ?? gas
        gasPrice = try? GasPrice(from: decoder)
        value = (try? container.decode(String.self, forKey: .value)).flatMap { BigUInt($0.drop0x, radix: 16) } ?? .zero
        nonce = (try? container.decode(String.self, forKey: .nonce)).flatMap { BigUInt($0.drop0x, radix: 16) }
        data = (try? container.decode(String.self, forKey: .data)).flatMap { Data.fromHex($0) } ?? Data()

        let to = (try? container.decode(String.self, forKey: .to)).flatMap { AlphaWallet.Address(string: $0) }
        if data.isEmpty || data.toHexString() == "0x" {
            recipient = to
            contract = nil
        } else {
            contract = to
            recipient = nil
        }
    }
}
