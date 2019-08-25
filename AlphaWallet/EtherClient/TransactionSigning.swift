// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import CryptoSwift

protocol Signer {
    func hash(transaction: UnsignedTransaction) -> Data
    func values(transaction: UnsignedTransaction, signature: Data) -> (r: BigInt, s: BigInt, v: BigInt)
}

struct EIP155Signer: Signer {
    private let server: RPCServer

    init(server: RPCServer) {
        self.server = server
    }

    func hash(transaction: UnsignedTransaction) -> Data {
        return rlpHash([
            transaction.nonce,
            transaction.gasPrice,
            transaction.gasLimit,
            transaction.to?.data ?? Data(),
            transaction.value,
            transaction.data,
            transaction.server.chainID, 0, 0,
        ] as [Any])!
    }

    func values(transaction: UnsignedTransaction, signature: Data) -> (r: BigInt, s: BigInt, v: BigInt) {
        let (r, s, v) = HomesteadSigner().values(transaction: transaction, signature: signature)
        let newV: BigInt
        if server.chainID != 0 {
            newV = BigInt(signature[64]) + 35 + BigInt(server.chainID) + BigInt(server.chainID)
        } else {
            newV = v
        }
        return (r, s, newV)
    }
}

struct HomesteadSigner: Signer {
    func hash(transaction: UnsignedTransaction) -> Data {
        return rlpHash([
            transaction.nonce,
            transaction.gasPrice,
            transaction.gasLimit,
            transaction.to?.data ?? Data(),
            transaction.value,
            transaction.data,
        ])!
    }

    func values(transaction: UnsignedTransaction, signature: Data) -> (r: BigInt, s: BigInt, v: BigInt) {
        precondition(signature.count == 65, "Wrong size for signature")
        let r = BigInt(sign: .plus, magnitude: BigUInt(signature[..<32]))
        let s = BigInt(sign: .plus, magnitude: BigUInt(signature[32..<64]))
        let v = BigInt(sign: .plus, magnitude: BigUInt(signature[64] + EthereumSigner.vitaliklizeConstant))
        return (r, s, v)
    }
}

func rlpHash(_ element: Any) -> Data? {
    let sha3 = SHA3(variant: .keccak256)
    guard let data = RLP.encode(element) else {
        return nil
    }
    return Data(bytes: sha3.calculate(for: data.bytes))
}
