// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import BigInt

struct UnsignedSwapTransaction: Codable {
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

    let server: RPCServer
    let data: Data
    let from: AlphaWallet.Address
    let to: AlphaWallet.Address
    let gasLimit: BigInt
    let gasPrice: BigInt
    let value: BigInt

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)

        let chainId = try container.decode(Int.self, forKey: .chainId)
        let dataString = try container.decode(String.self, forKey: .data)
        let fromString = try container.decode(String.self, forKey: .from)
        let toString = try container.decode(String.self, forKey: .to)
        let gasLimitString = try container.decode(String.self, forKey: .gasLimit)
        let gasPriceString = try container.decode(String.self, forKey: .gasPrice)
        let valueString = try container.decode(String.self, forKey: .value)

        server = RPCServer(chainID: chainId)
        data = Data(hex: dataString)
        from = try AlphaWallet.Address(string: fromString) ?? { throw ParsingError(fieldName: .from) }()
        to = try AlphaWallet.Address(string: toString) ?? { throw ParsingError(fieldName: .to) }()
        gasLimit = try BigInt(gasLimitString.drop0x, radix: 16) ?? { throw ParsingError(fieldName: .gasLimit) }()
        gasPrice = try BigInt(gasPriceString.drop0x, radix: 16) ?? { throw ParsingError(fieldName: .gasPrice) }()
        value = try BigInt(valueString.drop0x, radix: 16) ?? { throw ParsingError(fieldName: .value) }()
    }
}
