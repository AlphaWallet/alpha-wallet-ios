//
// Created by James Sangalli on 7/3/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import JSONRPCKit
import APIKit
import Result
import TrustKeystore
import JavaScriptKit
import Result

class ClaimOrderCoordinator {
    private let web3: Web3Swift
    private let server: RPCServer

    init(web3: Web3Swift, server: RPCServer) {
        self.web3 = web3
        self.server = server
    }

    //TODO indices are represented as UInt16 values, the new spec uses uint256. This is ok so long as the indices remain small enough
    func claimOrder(signedOrder: SignedOrder,
                    expiry: BigUInt,
                    v: UInt8,
                    r: String,
                    s: String,
                    contractAddress: String,
                    recipient: String,
                    completion: @escaping (Result<String, AnyError>) -> Void
        ) {

        if let tokenIds = signedOrder.order.tokenIds, !tokenIds.isEmpty {
            claimSpawnableOrder(expiry: expiry, tokenIds: tokenIds, v: v, r: r, s: s, recipient: recipient, contractAddress: contractAddress) { result in
                completion(result)
            }
        } else if signedOrder.order.nativeCurrencyDrop {
            claimNativeCurrency(signedOrder: signedOrder, v: v, r: r, s: s, recipient: recipient) { result in
                completion(result)
            }
        } else {
            claimNormalOrder(expiry: expiry, indices: signedOrder.order.indices, v: v, r: r, s: s, contractAddress: contractAddress) { result in
                completion(result)
            }
        }
    }
    
    func claimNormalOrder(expiry: BigUInt,
                          indices: [UInt16],
                          v: UInt8,
                          r: String,
                          s: String,
                          contractAddress: String,
                          completion: @escaping (Result<String, AnyError>) -> Void) {
        do {
            let encoder = ABIEncoder()
            let function = ClaimERC875OrderEncode()
            if contractAddress.isLegacy875Contract {
                try encoder.encode(signature: "trade(uint256,[uint16],uint8,bytes32,bytes32)")
                let tokenIndices = try indices.map({ BigUInt($0) })
                try encoder.encode(ABIValue(tokenIndices, type: ABIType.array(ABIType.uint(bits: 16), tokenIndices.count)))
            } else {
                try encoder.encode(signature: "trade(uint256,[uint256],uint8,bytes32,bytes32)")
                let tokenIndices = try indices.map({ BigUInt($0) })
                try encoder.encode(ABIValue(tokenIndices, type: ABIType.array(ABIType.uint(bits: 256), tokenIndices.count)))
            }
            let expiryParam = try encoder.encode(ABIValue(expiry, type: ABIType.uint(bits: 256)))
            let vParam = try encoder.encode(ABIValue(BigUInt(v), type: ABIType.uint(bits: 8)))
            let rParam = try encoder.encode(ABIValue(Data(hexString: r)!, type: ABIType.bytes(32)))
            let sParam = try encoder.encode(ABIValue(Data(hexString: s)!, type: ABIType.bytes(32)))
            callSmartContract(
                    withServer: server,
                    contract: Address(string: contractAddress)!,
                    functionName: function.name,
                    abiString: function.getAbi(contractAddress: contractAddress),
                    data: encoder.data
            ).done { result in
                if let res = result["0"] as? String {
                    completion(.success(res))
                } else {
                    completion(.failure(AnyError(Web3Error(description: "Error"))))
                }
            }
        } catch {
            completion(.failure(AnyError(Web3Error(description: "Error"))))
        }

    }

    func claimSpawnableOrder(expiry: BigUInt,
                             tokenIds: [BigUInt],
                             v: UInt8,
                             r: String,
                             s: String,
                             recipient: String,
                             contractAddress: String,
                             completion: @escaping (Result<String, AnyError>) -> Void) {
        do {
            let encoder = ABIEncoder()
            try encoder.encode(signature: "spawnPassTo(uint256,[uint256],uint8,bytes32,bytes32,address")
            let expiryParam = try encoder.encode(ABIValue(expiry, type: ABIType.uint(bits: 256)))
            let tokenIdsEncoded = try encoder.encode(ABIValue(tokenIds, type: ABIType.array(ABIType.uint(bits: 256), tokenIds.count)))
            let vParam = try encoder.encode(ABIValue(v, type: ABIType.uint(bits: 8)))
            let rParam = try encoder.encode(ABIValue(r, type: ABIType.bytes(32)))
            let sParam = try encoder.encode(ABIValue(s, type: ABIType.bytes(32)))
            let recipientEncoded = try encoder.encode(ABIValue(Address(string: recipient)!, type: ABIType.address))
            let function = ClaimERC875SpawnableEncode()
            callSmartContract(
                    withServer: server,
                    contract: Address(string: contractAddress)!,
                    functionName: function.name,
                    abiString: function.abi,
                    data: encoder.data
            ).done { result in
                if let res = result["0"] as? String {
                    completion(.success(res))
                } else {
                    completion(.failure(AnyError(Web3Error(description: "Error"))))
                }
            }
        } catch {
            completion(.failure(AnyError(Web3Error(description: "Error"))))
        }
    }

    func claimNativeCurrency(
            signedOrder: SignedOrder,
            v: UInt8,
            r: String,
            s: String,
            recipient: String,
            completion: @escaping (Result<String, AnyError>) -> Void
    ) {
        do {
            let function = ClaimNativeCurrencyOrder()
            let encoder = ABIEncoder()
            try encoder.encode(ABIValue(signedOrder.order.nonce, type: ABIType.uint(bits: 32)))
            try encoder.encode(ABIValue(signedOrder.order.expiry, type: ABIType.uint(bits: 32)))
            try encoder.encode(ABIValue(signedOrder.order.count, type: ABIType.uint(bits: 32)))
            try encoder.encode(ABIValue(BigUInt(v), type: ABIType.uint(bits: 8)))
            try encoder.encode(ABIValue(Data(hexString: r)!, type: ABIType.bytes(32)))
            try encoder.encode(ABIValue(Data(hexString: s)!, type: ABIType.bytes(32)))
            try encoder.encode(ABIValue(Address(string: recipient)!, type: ABIType.address))
            callSmartContract(
                    withServer: server,
                    contract: Address(string: signedOrder.order.contractAddress)!,
                    functionName: function.name,
                    abiString: function.abi,
                    data: encoder.data
            ).done { result in
                if let res = result["0"] as? String {
                    completion(.success(res))
                } else {
                    completion(.failure(AnyError(Web3Error(description: "Error"))))
                }
            }
        } catch {
            completion(.failure(AnyError(Web3Error(description: "Error"))))
        }
    }

    // TODO: Testing purposes only. Remove this when it is fully functional
    func startWeb3() {
        web3.start()
    }

}
