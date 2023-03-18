// Copyrights SIX DAY LLC. All rights reserved.

import BigInt
import Foundation

public struct EthereumTransaction {
    let blockHash: String
    let blockNumber: String
    let from: String
    let to: String
    let gas: String
    let gasPrice: String
    let hash: String
    let value: String
    let nonce: String
    let input: String
}

extension EthereumTransaction {
    public init(dictionary: [String: AnyObject]) {
        let blockHash = dictionary["blockHash"] as? String ?? ""
        let blockNumber = dictionary["blockNumber"] as? String ?? ""
        let gas = dictionary["gas"] as? String ?? "0"
        let gasPrice = dictionary["gasPrice"] as? String ?? "0"
        let hash = dictionary["hash"] as? String ?? ""
        let value = dictionary["value"] as? String ?? "0"
        let nonce = dictionary["nonce"] as? String ?? "0"
        let from = dictionary["from"] as? String ?? ""
        let to = dictionary["to"] as? String ?? ""
        let input = dictionary["input"] as? String ?? "0x"
        
        self.init(
            blockHash: blockHash,
            blockNumber: BigInt(blockNumber.drop0x, radix: 16)?.description ?? "",
            from: from,
            to: to,
            gas: BigInt(gas.drop0x, radix: 16)?.description ?? "",
            gasPrice: BigInt(gasPrice.drop0x, radix: 16)?.description ?? "",
            hash: hash,
            value: BigInt(value.drop0x, radix: 16)?.description ?? "",
            nonce: BigInt(nonce.drop0x, radix: 16)?.description ?? "",
            input: input)
    }
}
