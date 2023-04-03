// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt

public struct UnsignedSwapTransaction: Codable {
    private enum Keys: String, CodingKey {
        case chainId
        case data
        case from
        case to
        case gasLimit
        case gasPrice
        case value
    }

    private struct ParsingError: Error {
        let fieldName: Keys
    }

    public let server: RPCServer
    public let data: Data
    public let from: AlphaWallet.Address
    public let to: AlphaWallet.Address
    public let gasLimit: BigUInt?
    public let gasPrice: GasPrice?
    public let value: BigUInt

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        let chainId = try container.decode(Int.self, forKey: .chainId)
        let dataString = try container.decode(String.self, forKey: .data)
        let fromString = try container.decode(String.self, forKey: .from)
        let toString = try container.decode(String.self, forKey: .to)
        let gasLimitString = try container.decodeIfPresent(String.self, forKey: .gasLimit)
        let valueString = try container.decode(String.self, forKey: .value)

        server = RPCServer(chainID: chainId)
        data = Data(hex: dataString)
        from = try AlphaWallet.Address(string: fromString) ?? { throw ParsingError(fieldName: .from) }()
        to = try AlphaWallet.Address(string: toString) ?? { throw ParsingError(fieldName: .to) }()
        gasLimit = try gasLimitString.flatMap { BigUInt($0.drop0x, radix: 16) }
        gasPrice = try? GasPrice(from: decoder)
        value = try BigUInt(valueString.drop0x, radix: 16) ?? { throw ParsingError(fieldName: .value) }()
    }
}
