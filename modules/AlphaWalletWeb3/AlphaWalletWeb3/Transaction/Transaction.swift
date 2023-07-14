//
//  EthereumTransaction.swift
//  web3swift
//
//  Created by Alexander Vlasov on 05.12.2017.
//  Copyright © 2017 Alexander Vlasov. All rights reserved.
//

import Foundation
import BigInt

struct Transaction: CustomStringConvertible {
    var nonce: BigUInt
    var gasPrice: BigUInt = BigUInt(0)
    var gasLimit: BigUInt = BigUInt(0)
    var to: EthereumAddress
    var value: BigUInt
    var data: Data
    var v: BigUInt = BigUInt(1)
    var r: BigUInt = BigUInt(0)
    var s: BigUInt = BigUInt(0)
    var chainID: BigUInt?

    var inferedChainID: BigUInt? {
        if self.r == BigUInt(0) && self.s == BigUInt(0) {
            return self.v
        } else if self.v == BigUInt(27) || self.v == BigUInt(28) {
            return nil
        } else {
            return ((self.v - BigUInt(1)) / BigUInt(2)) - BigUInt(17)
        }
    }

    var intrinsicChainID: BigUInt? {
        return self.chainID
    }

    mutating func UNSAFE_setChainID(_ chainID: BigUInt?) {
        self.chainID = chainID
    }

    var hash: Data? {
        var encoded: Data
        if inferedChainID != nil {
            guard let enc = encode(forSignature: false, chainID: inferedChainID) else { return nil }
            encoded = enc
        } else {
            guard let enc = encode(forSignature: false, chainID: chainID) else { return nil }
            encoded = enc
        }
        return encoded.sha3(.keccak256)
    }

    init(gasPrice: BigUInt, gasLimit: BigUInt, to: EthereumAddress, value: BigUInt, data: Data) {
        self.nonce = BigUInt(0)
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.value = value
        self.data = data
        self.to = to
    }

    init(to: EthereumAddress, data: Data, options: Web3Options) {
        let defaults = Web3Options.defaultOptions()
        let merged = Web3Options.merge(defaults, with: options)
        self.nonce = BigUInt(0)
        self.gasLimit = merged.gasLimit!
        self.gasPrice = merged.gasPrice!
        self.value = merged.value!
        self.to = to
        self.data = data
    }

    init (nonce: BigUInt, gasPrice: BigUInt, gasLimit: BigUInt, to: EthereumAddress, value: BigUInt, data: Data, v: BigUInt, r: BigUInt, s: BigUInt) {
        self.nonce = nonce
        self.gasPrice = gasPrice
        self.gasLimit = gasLimit
        self.to = to
        self.value = value
        self.data = data
        self.v = v
        self.r = r
        self.s = s
    }

    func mergedWithOptions(_ options: Web3Options) -> Transaction {
        var tx = self
        if let gasPrice = options.gasPrice {
            tx.gasPrice = gasPrice
        }
        if let gasLimit = options.gasLimit {
            tx.gasLimit = gasLimit
        }
        if let value = options.value {
            tx.value = value
        }
        if let to = options.to {
            tx.to = to
        }
        return tx
    }

    var description: String {
        var toReturn = ""
        toReturn += "Transaction" + "\n"
        toReturn += "Nonce: " + String(self.nonce) + "\n"
        toReturn += "Gas price: " + String(self.gasPrice) + "\n"
        toReturn += "Gas limit: " + String(describing: self.gasLimit) + "\n"
        toReturn += "To: " + self.to.address  + "\n"
        toReturn += "Value: " + String(self.value) + "\n"
        toReturn += "Data: " + self.data.toHexString().addHexPrefix().lowercased() + "\n"
        toReturn += "v: " + String(self.v) + "\n"
        toReturn += "r: " + String(self.r) + "\n"
        toReturn += "s: " + String(self.s) + "\n"
        toReturn += "Intrinsic chainID: " + String(describing: self.chainID) + "\n"
        toReturn += "Infered chainID: " + String(describing: self.inferedChainID) + "\n"
        toReturn += "sender: " + String(describing: self.sender?.address)  + "\n"
        toReturn += "hash: " + String(describing: self.hash?.toHexString().addHexPrefix()) + "\n"

        return toReturn
    }
    var sender: EthereumAddress? {
        guard let publicKey = self.recoverPublicKey() else { return nil }
        return Web3.Utils.publicToAddress(publicKey)
    }

    func recoverPublicKey() -> Data? {
        if self.r == BigUInt(0) && self.s == BigUInt(0) {
            return nil
        }
        var normalizedV: BigUInt = BigUInt(0)
        let inferedChainID = self.inferedChainID
        if self.chainID != nil && self.chainID != BigUInt(0) {
            normalizedV = self.v - BigUInt(35) - self.chainID! - self.chainID!
        } else if inferedChainID != nil {
            normalizedV = self.v - BigUInt(35) - inferedChainID! - inferedChainID!
        } else {
            normalizedV = self.v - BigUInt(27)
        }
        guard let vData = normalizedV.serialize().setLengthLeft(1) else { return nil }
        guard let rData = r.serialize().setLengthLeft(32) else { return nil }
        guard let sData = s.serialize().setLengthLeft(32) else { return nil }
        guard let signatureData = SECP256K1.marshalSignature(v: vData, r: rData, s: sData) else { return nil }
        var hash: Data
        if inferedChainID != nil {
            guard let h = self.hashForSignature(chainID: inferedChainID) else { return nil }
            hash = h
        } else {
            guard let h = self.hashForSignature(chainID: self.chainID) else { return nil }
            hash = h
        }
        return SECP256K1.recoverPublicKey(hash: hash, signature: signatureData)
    }

    var txhash: String? {
        guard self.sender != nil else { return nil }
        guard let hash = self.hash else { return nil }

        return hash.toHexString().addHexPrefix().lowercased()
    }

    var txid: String? {
        return self.txhash
    }

    func encode(forSignature: Bool = false, chainID: BigUInt? = nil) -> Data? {
        if forSignature {
            if chainID != nil {
                let fields = [self.nonce, self.gasPrice, self.gasLimit, self.to.addressData, self.value, self.data, chainID!, BigUInt(0), BigUInt(0)] as [AnyObject]
                return RLP.encode(fields)
            } else if self.chainID != nil {
                let fields = [self.nonce, self.gasPrice, self.gasLimit, self.to.addressData, self.value, self.data, self.chainID!, BigUInt(0), BigUInt(0)] as [AnyObject]
                return RLP.encode(fields)
            } else {
                let fields = [self.nonce, self.gasPrice, self.gasLimit, self.to.addressData, self.value, self.data] as [AnyObject]
                return RLP.encode(fields)
            }
        } else {
            let fields = [self.nonce, self.gasPrice, self.gasLimit, self.to.addressData, self.value, self.data, self.v, self.r, self.s] as [AnyObject]
            return RLP.encode(fields)
        }
    }

    func encodeAsDictionary(from: EthereumAddress? = nil) -> TransactionParameters {
        var toString: String?
        switch self.to.type {
        case .normal:
            toString = self.to.address.lowercased()
        case .contractDeployment:
            break
        }
        var params = TransactionParameters(from: from?.address.lowercased(), to: toString)
        let gasEncoding = self.gasLimit.abiEncode(bits: 256)
        params.gas = gasEncoding?.toHexString().addHexPrefix().stripLeadingZeroes()
        let gasPriceEncoding = self.gasPrice.abiEncode(bits: 256)
        params.gasPrice = gasPriceEncoding?.toHexString().addHexPrefix().stripLeadingZeroes()
        let valueEncoding = self.value.abiEncode(bits: 256)
        params.value = valueEncoding?.toHexString().addHexPrefix().stripLeadingZeroes()
        if self.data != Data() {
            params.data = self.data.toHexString().addHexPrefix()
        } else {
            params.data = "0x"
        }
        return params
    }

    func hashForSignature(chainID: BigUInt? = nil) -> Data? {
        guard let encoded = self.encode(forSignature: true, chainID: chainID) else { return nil }
        return encoded.sha3(.keccak256)
    }

    static func fromJSON(_ json: [String: Any]) -> Transaction? {
        guard let options = Web3Options.fromJSON(json) else { return nil }
        guard let toString = json["to"] as? String else { return nil }
        var to: EthereumAddress
        if toString == "0x" || toString == "0x0" {
            to = EthereumAddress.contractDeploymentAddress()
        } else {
            guard let ethAddr = EthereumAddress(toString) else { return nil }
            to = ethAddr
        }
//        if (!to.isValid) {
//            return nil
//        }
        var dataString = json["data"] as? String
        if dataString == nil {
            dataString = json["input"] as? String
        }
        guard dataString != nil, let data = Data.fromHex(dataString!) else { return nil }
        var transaction = Transaction(to: to, data: data, options: options)
        if let nonceString = json["nonce"] as? String {
            guard let nonce = BigUInt(nonceString.stripHexPrefix(), radix: 16) else { return nil }
            transaction.nonce = nonce
        }
        if let vString = json["v"] as? String {
            guard let v = BigUInt(vString.stripHexPrefix(), radix: 16) else { return nil }
            transaction.v = v
        }
        if let rString = json["r"] as? String {
            guard let r = BigUInt(rString.stripHexPrefix(), radix: 16) else { return nil }
            transaction.r = r
        }
        if let sString = json["s"] as? String {
            guard let s = BigUInt(sString.stripHexPrefix(), radix: 16) else { return nil }
            transaction.s = s
        }
        if let valueString = json["value"] as? String {
            guard let value = BigUInt(valueString.stripHexPrefix(), radix: 16) else { return nil }
            transaction.value = value
        }
        let inferedChainID = transaction.inferedChainID
        if transaction.inferedChainID != nil && transaction.v >= BigUInt(37) {
            transaction.chainID = inferedChainID
        }
//        let hash = json["hash"] as? String
//        if hash != nil {
//            let calculatedHash = transaction.hash
//            let receivedHash = Data.fromHex(hash!)
//            if (receivedHash != calculatedHash) {
//                print("hash mismatch, dat")
//                print(String(describing: transaction))
//                print(json)
//                return nil
//            }
//        }
        return transaction
    }

    static func fromRaw(_ raw: Data) -> Transaction? {
        guard let totalItem = RLP.decode(raw) else { return nil }
        guard let rlpItem = totalItem[0] else { return nil }
        switch rlpItem.count {
        case 9?:
            guard let nonceData = rlpItem[0]!.data else { return nil }
            let nonce = BigUInt(nonceData)
            guard let gasPriceData = rlpItem[1]!.data else { return nil }
            let gasPrice = BigUInt(gasPriceData)
            guard let gasLimitData = rlpItem[2]!.data else { return nil }
            let gasLimit = BigUInt(gasLimitData)
            var to: EthereumAddress
            switch rlpItem[3]!.content {
            case .noItem:
                to = EthereumAddress.contractDeploymentAddress()
            case .data(let addressData):
                if addressData.isEmpty {
                    to = EthereumAddress.contractDeploymentAddress()
                } else if addressData.count == 20 {
                    guard let addr = EthereumAddress(addressData) else { return nil }
                    to = addr
                } else {
                    return nil
                }
            case .list:
                return nil
            }
            guard let valueData = rlpItem[4]!.data else { return nil }
            let value = BigUInt(valueData)
            guard let transactionData = rlpItem[5]!.data else { return nil }
            guard let vData = rlpItem[6]!.data else { return nil }
            let v = BigUInt(vData)
            guard let rData = rlpItem[7]!.data else { return nil }
            let r = BigUInt(rData)
            guard let sData = rlpItem[8]!.data else { return nil }
            let s = BigUInt(sData)
            return Transaction.init(nonce: nonce, gasPrice: gasPrice, gasLimit: gasLimit, to: to, value: value, data: transactionData, v: v, r: r, s: s)
        case 6?:
            return nil
        default:
            return nil
        }
    }

    static func createRequest(method: JSONRPCmethod, transaction: Transaction, onBlock: String? = nil, options: Web3Options?) -> JSONRPCrequest? {
        var txParams = transaction.encodeAsDictionary(from: options?.from)
        if method == .estimateGas || options?.gasLimit == nil {
            txParams.gas = nil
        }
        if let excludeZeroGasPrice = options?.excludeZeroGasPrice, excludeZeroGasPrice && txParams.gasPrice == "0x0" {
            txParams.gasPrice = nil
        }
        var params = [txParams] as [Encodable]
        if method.requiredNumOfParameters == 2 && onBlock != nil {
            params.append(onBlock as Encodable)
        }
        let request = JSONRPCrequest(method: method, params: JSONRPCparams(params: params))
        if !request.isValid { return nil }

        return request
    }

    static func createRawTransaction(transaction: Transaction) -> JSONRPCrequest? {
        guard transaction.sender != nil else { return nil }
        guard let encodedData = transaction.encode() else { return nil }
        let hex = encodedData.toHexString().addHexPrefix().lowercased()
        let request = JSONRPCrequest(method: JSONRPCmethod.sendRawTransaction, params: JSONRPCparams(params: [hex]))
        if !request.isValid { return nil }
        return request
    }
}
