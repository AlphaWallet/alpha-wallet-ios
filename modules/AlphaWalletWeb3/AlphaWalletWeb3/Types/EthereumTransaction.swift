// Copyrights SIX DAY LLC. All rights reserved.

import BigInt
import Foundation

public struct EthereumTransaction {
    public let blockHash: String
    public let blockNumber: String
    public let from: String
    public let to: String
    public let gas: String
    public let gasPrice: GasPrice?
    public let hash: String
    public let input: String
    public let value: String
    public let nonce: String
    public let transactionIndex: String
}

extension EthereumTransaction {

    public init(dictionary: [String: AnyObject]) {
        let blockHash = dictionary["blockHash"] as? String ?? ""
        let blockNumber = dictionary["blockNumber"] as? String ?? ""
        let gas = dictionary["gas"] as? String ?? "0"
        let hash = dictionary["hash"] as? String ?? ""
        let value = dictionary["value"] as? String ?? "0"
        let nonce = dictionary["nonce"] as? String ?? "0"
        let from = dictionary["from"] as? String ?? ""
        let to = dictionary["to"] as? String ?? ""

        let gasPrice = GasPrice(dictionary)

        let input = dictionary["input"] as? String ?? "0x"
        let transactionIndex = dictionary["transactionIndex"] as? String ?? "0"

        self.init(
            blockHash: blockHash,
            blockNumber: BigInt(blockNumber.drop0x, radix: 16)?.description ?? "",
            from: from,
            to: to,
            gas: BigInt(gas.drop0x, radix: 16)?.description ?? "",
            gasPrice: gasPrice,
            hash: hash,
            input: input,
            value: BigInt(value.drop0x, radix: 16)?.description ?? "",
            nonce: BigInt(nonce.drop0x, radix: 16)?.description ?? "",
            transactionIndex: transactionIndex)
    }
}

fileprivate extension GasPrice {
    init?(_ object: [String: AnyObject]) {
        let type = object["type"] as? String ?? ""
        if type == "0x2" {
            guard let maxFeePerGas = (object["maxFeePerGas"] as? String).flatMap({ BigUInt($0.drop0x, radix: 16) }),
                let maxPriorityFeePerGas = (object["maxPriorityFeePerGas"] as? String).flatMap({ BigUInt($0.drop0x, radix: 16) }) else {
                    return nil
                }
            self = .eip1559(maxFeePerGas: maxFeePerGas, maxPriorityFeePerGas: maxPriorityFeePerGas)
        } else {
            guard let gasPrice = (object["gasPrice"] as? String).flatMap({ BigUInt($0.drop0x, radix: 16) }) else { return nil }
            self = .legacy(gasPrice: gasPrice)
        }
    }
}
