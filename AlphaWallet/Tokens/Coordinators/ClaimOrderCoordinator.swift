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
            let function = ClaimERC875OrderEncode()
            let expiryParam = try ABIValue(expiry, type: ABIType.uint(bits: 256))
            let tokenIndices: [ABIValue]
            if contractAddress.isLegacy875Contract {
                tokenIndices = try indices.map({ try ABIValue(BigUInt($0), type: ABIType.uint(bits: 16)) })
            } else {
                tokenIndices = try indices.map({ try ABIValue(BigUInt($0), type: ABIType.uint(bits: 256)) })
            }
            let vParam = try ABIValue(BigUInt(v), type: ABIType.uint(bits: 8))
            let rParam = try ABIValue(Data(hexString: r)!, type: ABIType.bytes(32))
            let sParam = try ABIValue(Data(hexString: s)!, type: ABIType.bytes(32))
            let parameters = [expiryParam, tokenIndices, vParam, rParam, sParam] as [AnyObject]
            callSmartContract(
                    withServer: server,
                    contract: Address(string: contractAddress)!,
                    functionName: function.name,
                    abiString: function.getAbi(contractAddress: contractAddress),
                    parameters: parameters
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
            let expiryParam = try ABIValue(expiry, type: ABIType.uint(bits: 256))
            let tokenIdsEncoded = tokenIdsEncoded = try tokenIds.map({ try ABIValue($0, type: ABIType.uint(bits: 256)) })
            let vParam = try ABIValue(v, type: ABIType.uint(bits: 8))
            let rParam = try ABIValue(r, type: ABIType.bytes(32))
            let sParam = try ABIValue(s, type: ABIType.bytes(32))
            let recipientEncoded = try ABIValue(Address(string: recipient)!, type: ABIType.address)
            let parameters = [expiryParam, tokenIdsEncoded, vParam, rParam, sParam, recipientEncoded] as [AnyObject]
            let function = ClaimERC875SpawnableEncode()
            callSmartContract(
                    withServer: server,
                    contract: Address(string: contractAddress)!,
                    functionName: function.name,
                    abiString: function.abi,
                    parameters: parameters
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
            let parameters = [
                try ABIValue(signedOrder.order.nonce, type: ABIType.uint(bits: 32)),
                try ABIValue(signedOrder.order.expiry, type: ABIType.uint(bits: 32)),
                try ABIValue(signedOrder.order.count, type: ABIType.uint(bits: 32)),
                try ABIValue(BigUInt(v), type: ABIType.uint(bits: 8)),
                try ABIValue(Data(hexString: r)!, type: ABIType.bytes(32)),
                try ABIValue(Data(hexString: s)!, type: ABIType.bytes(32)),
                try ABIValue(Address(string: recipient)!, type: ABIType.address)
            ] as [AnyObject]
            callSmartContract(
                    withServer: server,
                    contract: Address(string: signedOrder.order.contractAddress)!,
                    functionName: function.name,
                    abiString: function.abi,
                    parameters: parameters
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
