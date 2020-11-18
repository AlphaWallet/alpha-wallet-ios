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
    func claimOrder(signedOrder: SignedOrder,
                    expiry: BigUInt,
                    v: UInt8,
                    r: String,
                    s: String,
                    contractAddress: AlphaWallet.Address,
                    recipient: AlphaWallet.Address,
                    completion: @escaping (Swift.Result<Data, AnyError>) -> Void
        ) {

        if let tokenIds = signedOrder.order.tokenIds, !tokenIds.isEmpty {
            claimSpawnableOrder(expiry: expiry, tokenIds: tokenIds, v: v, r: r, s: s, recipient: recipient) { result in
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
                          contractAddress: AlphaWallet.Address,
                          completion: @escaping (Swift.Result<Data, AnyError>) -> Void) {
        do {
            let parameters: [Any] = [expiry, indices.map({ BigUInt($0) }), BigUInt(v), Data(hex: r), Data(hex: s)]
            let arrayType: ABIType
            if contractAddress.isLegacy875Contract {
                arrayType = ABIType.uint(bits: 16)
            } else {
                arrayType = ABIType.uint(bits: 256)
            }
            //trade(uint256,uint16[],uint8,bytes32,bytes32)
            let functionEncoder = Function(name: "trade", parameters: [
                .uint(bits: 256),
                .dynamicArray(arrayType),
                .uint(bits: 8),
                .bytes(32),
                .bytes(32)
            ])
            let encoder = ABIEncoder()
            try encoder.encode(function: functionEncoder, arguments: parameters)
            completion(.success(encoder.data))
        } catch {
            completion(.failure(AnyError(Web3Error(description: "malformed transaction"))))
        }
    }

    func claimSpawnableOrder(expiry: BigUInt,
                             tokenIds: [BigUInt],
                             v: UInt8,
                             r: String,
                             s: String,
                             recipient: AlphaWallet.Address,
                             completion: @escaping (Swift.Result<Data, AnyError>) -> Void) {

        do {
            let parameters: [Any] = [expiry, tokenIds, BigUInt(v), Data(hex: r), Data(hex: s), TrustKeystore.Address(address: recipient)]
            let functionEncoder = Function(name: "spawnPassTo", parameters: [
                .uint(bits: 256),
                .dynamicArray(.uint(bits: 256)),
                .uint(bits: 8),
                .bytes(32),
                .bytes(32),
                .address
            ])
            let encoder = ABIEncoder()
            try encoder.encode(function: functionEncoder, arguments: parameters)
            completion(.success(encoder.data))
        } catch {
            completion(.failure(AnyError(Web3Error(description: "malformed transaction"))))
        }
    }

    func claimNativeCurrency(
            signedOrder: SignedOrder,
            v: UInt8,
            r: String,
            s: String,
            recipient: AlphaWallet.Address,
        completion: @escaping (Swift.Result<Data, AnyError>) -> Void
    ) {
        do {
            let parameters: [Any] = [
                signedOrder.order.nonce,
                signedOrder.order.expiry,
                signedOrder.order.count,
                BigUInt(v),
                Data(hex: r),
                Data(hex: s),
                Address(address: recipient)
            ]
            let functionEncoder = Function(name: "dropCurrency", parameters: [
                .uint(bits: 256),
                .uint(bits: 256),
                .uint(bits: 256),
                .uint(bits: 8),
                .bytes(32),
                .bytes(32),
                .address
            ])
            let encoder = ABIEncoder()
            try encoder.encode(function: functionEncoder, arguments: parameters)
            completion(.success(encoder.data))
        } catch {
            completion(.failure(AnyError(Web3Error(description: "malformed transaction"))))
        }
    }
}
