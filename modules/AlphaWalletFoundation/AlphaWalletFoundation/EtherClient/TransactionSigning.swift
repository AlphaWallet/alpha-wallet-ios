// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import CryptoSwift

public protocol Signer {
    func hash(transaction: UnsignedTransaction) throws -> Data
    func values(transaction: UnsignedTransaction, signature: Data) -> (r: BigInt, s: BigInt, v: BigInt)
}

public struct EIP155Signer: Signer {
    private let server: RPCServer

    public init(server: RPCServer) {
        self.server = server
    }

    public func hash(transaction: UnsignedTransaction) throws -> Data {
        enum AnyError: Error {
            case invalid
        }

        let values: [Any] = [
            transaction.nonce,
            transaction.gasPrice,
            transaction.gasLimit,
            transaction.to?.data ?? Data(),
            transaction.value,
            transaction.data,
            transaction.server.chainID, 0, 0,
        ]

        guard let data = rlpHash(values) else {
            throw AnyError.invalid
        }
        return data
    }

    public func values(transaction: UnsignedTransaction, signature: Data) -> (r: BigInt, s: BigInt, v: BigInt) {
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

public struct HomesteadSigner: Signer {
    public init() { }
    public func hash(transaction: UnsignedTransaction) -> Data {
        return rlpHash([
            transaction.nonce,
            transaction.gasPrice,
            transaction.gasLimit,
            transaction.to?.data ?? Data(),
            transaction.value,
            transaction.data,
        ])!
    }

    public func values(transaction: UnsignedTransaction, signature: Data) -> (r: BigInt, s: BigInt, v: BigInt) {
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
