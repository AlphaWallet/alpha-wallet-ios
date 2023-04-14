// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import CryptoSwift

public struct EthereumSignature {
    public let v: UInt8
    public let r: Data
    public let s: Data

    public init(v: UInt8, r: Data, s: Data) {
        self.v = v
        self.r = r
        self.s = s
    }

    public init(serialized: Data) {
        let bytes = [UInt8](serialized)

        var v = bytes[bytes.count-1]
        if v >= EthereumSigner.vitaliklizeConstant && v <= 30 {
            v -= EthereumSigner.vitaliklizeConstant
        } else if v >= 31 && v <= 34 {
            v -= 31
        } else if v >= 35 && v <= 38 {
            v -= 35
        }

        self.v = v
        self.r = Data(bytes: bytes[0..<32])
        self.s = Data(bytes: bytes[32..<64])
    }
}

public protocol TransactionSigner {
    func sign(transaction: UnsignedTransaction, privateKey: Data) throws -> Data
    func rlpEncodedHash(transaction: UnsignedTransaction) throws -> Data
}

enum SignerError: Error {
    case rplEncodeFailure
}

public struct EIP155Signer: TransactionSigner {

    private let server: RPCServer

    public init(server: RPCServer) {
        self.server = server
    }

    public func sign(transaction: UnsignedTransaction, privateKey: Data) throws -> Data {
        let rlpEncodedHash = try rlpEncodedHash(transaction: transaction)
        let signatureData = try EthereumSigner().sign(hash: rlpEncodedHash, withPrivateKey: privateKey)
        let signature = signature(transaction: transaction, signatureData: signatureData)
        return try rlpEncoded(transaction: transaction, with: signature)
    }

    func rlpEncoded(transaction: UnsignedTransaction, with signature: EthereumSignature) throws -> Data {
        switch transaction.gasPrice {
        case .legacy(let legacyGasPrice):
            let values: [Any] = [
                transaction.nonce,
                legacyGasPrice,
                transaction.gasLimit,
                transaction.to?.data ?? Data(),
                transaction.value,
                transaction.data,
                signature.v,
                signature.r,
                signature.s
            ]

            //NOTE: avoid app crash, returns with return error, Happens when amount to send less then 0
            guard let data = RLP.encode(values) else { throw SignerError.rplEncodeFailure }

            return data
        case .eip1559(let maxFeePerGas, let maxPriorityFeePerGas):
            let values: [Any] = [
                transaction.server.chainID,
                transaction.nonce,
                maxPriorityFeePerGas,
                maxFeePerGas,
                transaction.gasLimit,
                transaction.to?.data ?? Data(),
                transaction.value,
                transaction.data,
                [],
                signature.v,
                signature.r,
                signature.s
            ]

            guard let encodedTransaction = RLP.encode(values) else { throw SignerError.rplEncodeFailure }

            return Data([0x02]) + encodedTransaction
        }
    }

    public func rlpEncodedHash(transaction: UnsignedTransaction) throws -> Data {
        switch transaction.gasPrice {
        case .legacy(let gasPrice):
            return try rlpEncodeForLegacyGasPriceHash(transaction: transaction, legacyGasPrice: gasPrice)
        case .eip1559(let maxFeePerGas, let maxPriorityFeePerGas):
            return try rlpEncodeForEip1559Hash(transaction: transaction, maxFeePerGas: maxFeePerGas, maxPriorityFeePerGas: maxPriorityFeePerGas)
        }
    }

    private func rlpEncodeForLegacyGasPriceHash(transaction: UnsignedTransaction, legacyGasPrice: BigUInt) throws -> Data {
        let values: [Any] = [
            transaction.nonce,
            legacyGasPrice,
            transaction.gasLimit,
            transaction.to?.data ?? Data(),
            transaction.value,
            transaction.data,
            transaction.server.chainID, 0, 0,
        ]

        guard let data = rlpHash(values) else { throw SignerError.rplEncodeFailure }
        return data
    }

    private func rlpEncodeForEip1559Hash(transaction: UnsignedTransaction, maxFeePerGas: BigUInt, maxPriorityFeePerGas: BigUInt) throws -> Data {
        let values: [Any] = [
            transaction.server.chainID,
            transaction.nonce,
            maxPriorityFeePerGas,
            maxFeePerGas,
            transaction.gasLimit,
            transaction.to?.data ?? Data(),
            transaction.value,
            transaction.data,
            [],
        ]

        guard let data = RLP.encode(values) else { throw SignerError.rplEncodeFailure }
        return Data(bytes: ([0x02] + data.bytes).sha3(.keccak256))
    }

    public func signature(transaction: UnsignedTransaction, signatureData: Data) -> EthereumSignature {
        switch transaction.gasPrice {
        case .legacy:
            return signatureLegacy(from: signatureData)
        case .eip1559:
            return signatureEip1559(from: signatureData)
        }
    }

    private func signatureLegacy(from data: Data) -> EthereumSignature {
        return EthereumSignature(
            v: server.chainID == 0 ? data[64] + EthereumSigner.vitaliklizeConstant : data[64] + 35 + UInt8(server.chainID * 2),
            r: Data(bytes: data[..<32]),
            s: Data(bytes: data[32..<64]))
    }

    private func signatureEip1559(from data: Data) -> EthereumSignature {
        return EthereumSignature(
            v: data[64],
            r: Data(bytes: data[..<32]),
            s: Data(bytes: data[32..<64]))
    }
}

public struct HomesteadSigner: TransactionSigner {

    public func sign(transaction: UnsignedTransaction, privateKey: Data) throws -> Data {
        let rlpEncodedHash = try rlpEncodedHash(transaction: transaction)
        let signatureData = try EthereumSigner().sign(hash: rlpEncodedHash, withPrivateKey: privateKey)
        let signature = signature(transaction: transaction, signatureData: signatureData)
        return try rlpEncoded(transaction: transaction, with: signature)
    }

    public func rlpEncoded(transaction: UnsignedTransaction, with signature: EthereumSignature) throws -> Data {
        let values: [Any] = [
            transaction.nonce,
            transaction.gasPrice,
            transaction.gasLimit,
            transaction.to?.data ?? Data(),
            transaction.value,
            transaction.data,
        ]

        guard let data = RLP.encode(values) else { throw SignerError.rplEncodeFailure }
        return data
    }

    public init() { }

    public func rlpEncodedHash(transaction: UnsignedTransaction) throws -> Data {
        let values: [Any] = [
            transaction.nonce,
            transaction.gasPrice.max,
            transaction.gasLimit,
            transaction.to?.data ?? Data(),
            transaction.value,
            transaction.data,
        ]

        guard let data = rlpHash(values) else { throw SignerError.rplEncodeFailure }
        return data
    }

    public func signature(transaction: UnsignedTransaction, signatureData data: Data) -> EthereumSignature {
        precondition(data.count == 65, "Wrong size for signature")
        return EthereumSignature(
            v: data[64] + EthereumSigner.vitaliklizeConstant,
            r: Data(bytes: data[..<32]),
            s: Data(bytes: data[32..<64]))
    }
}

fileprivate func rlpHash(_ element: Any) -> Data? {
    let sha3 = SHA3(variant: .keccak256)
    guard let data = RLP.encode(element) else {
        return nil
    }
    return Data(bytes: sha3.calculate(for: data.bytes))
}
