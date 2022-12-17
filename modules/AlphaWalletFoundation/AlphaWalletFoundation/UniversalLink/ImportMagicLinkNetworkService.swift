//
//  ImportMagicLinkNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 15.12.2022.
//

import Foundation
import BigInt
import Combine
import AlphaWalletCore

public class ImportMagicLinkNetworking {
    private let networkService: NetworkService

    public init(networkService: NetworkService) {
        self.networkService = networkService
    }

    public func checkPaymentServerSupportsContract(contractAddress: AlphaWallet.Address) -> AnyPublisher<Bool, Never> {
        networkService
            .dataTaskPublisher(CheckPaymentServerSupportsContractRequest(contractAddress: contractAddress))
            .map { $0.response.statusCode >= 200 && $0.response.statusCode <= 299 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func checkIfLinkClaimed(r: String) -> AnyPublisher<Bool, Never> {
        networkService
            .dataTaskPublisher(CheckIfLinkClaimedRequest(r: r))
            .map { $0.response.statusCode == 208 || $0.response.statusCode > 299 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    public func freeTransfer(request: FreeTransferRequest) -> AnyPublisher<Bool, Never> {
        networkService
            .dataTaskPublisher(request)
            .map {
                //need to set this to false by default else it will allow no connections to be considered successful etc
                //401 code will be given if signature is invalid on the server
                return $0.response.statusCode < 300
            }.replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

extension ImportMagicLinkNetworking {
    public struct FreeTransferRequest: URLRequestConvertible {

        public var contractAddress: AlphaWallet.Address {
            signedOrder.order.contractAddress
        }

        let signedOrder: SignedOrder
        let wallet: Wallet
        let server: RPCServer

        public init(signedOrder: SignedOrder, wallet: Wallet, server: RPCServer) {
            self.signedOrder = signedOrder
            self.wallet = wallet
            self.server = server
        }

        public func asURLRequest() throws -> URLRequest {
            switch signedOrder.order.nativeCurrencyDrop {
            case true:
                return try FreeTransferRequestForCurrencyLinks(signedOrder: signedOrder, recipient: wallet.address, server: server).asURLRequest()
            case false:
                return try FreeTransferRequestForNormalLinks(signedOrder: signedOrder, isForTransfer: true, wallet: wallet, server: server).asURLRequest()
            }
        }
    }

    private struct FreeTransferRequestForNormalLinks: URLRequestConvertible {
        let signedOrder: SignedOrder
        let isForTransfer: Bool
        let wallet: Wallet
        let server: RPCServer

        private func stringEncodeIndices(_ indices: [UInt16]) -> String {
            return indices.map(String.init).joined(separator: ",")
        }

        private func stringEncodeTokenIds(_ tokenIds: [BigUInt]?) -> String? {
            guard let tokens = tokenIds else { return nil }
            return tokens.map({ $0.serialize().hexString }).joined(separator: ",")
        }

        func asURLRequest() throws -> URLRequest {
            let signature = signedOrder.signature.drop0x
            let indices = signedOrder.order.indices
            let indicesStringEncoded = stringEncodeIndices(indices)
            let tokenIdsEncoded = stringEncodeTokenIds(signedOrder.order.tokenIds)
            var parameters: Parameters = [
                "address": wallet.address,
                "contractAddress": signedOrder.order.contractAddress,
                "indices": indicesStringEncoded,
                "tokenIds": tokenIdsEncoded ?? "",
                "price": signedOrder.order.price.description,
                "expiry": signedOrder.order.expiry.description,
                "v": signature.substring(from: 128),
                "r": "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64))),
                "s": "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128))),
                "networkId": server.chainID.description,
            ]

            if isForTransfer {
                parameters.removeValue(forKey: "price")
            }

            guard var components = URLComponents(url: Constants.paymentServerBaseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }

            if signedOrder.order.spawnable {
                parameters.removeValue(forKey: "indices")
                components.path = "/api/claimSpawnableToken"
            } else {
                parameters.removeValue(forKey: "tokenIds")
                components.path = "/api/claimToken"
            }

            var request = try URLRequest(url: components.asURL(), method: .get)
            return try URLEncoding().encode(request, with: parameters)
        }
    }

    private struct FreeTransferRequestForCurrencyLinks: URLRequestConvertible {
        let signedOrder: SignedOrder
        let recipient: AlphaWallet.Address
        let server: RPCServer

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.paymentServerBaseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/claimFreeCurrency"

            var request = try URLRequest(url: components.asURL(), method: .get)
            let signature = signedOrder.signature.drop0x

            return try URLEncoding().encode(request, with: [
                "prefix": Constants.xdaiDropPrefix,
                "recipient": recipient.eip55String,
                "amount": signedOrder.order.count.description,
                "expiry": signedOrder.order.expiry.description,
                "nonce": signedOrder.order.nonce,
                "v": signature.substring(from: 128),
                //Use string interpolation instead of concatenation to speed up build time. 160ms -> <100ms, as of Xcode 11.7
                "r": "0x\(signature.substring(with: Range(uncheckedBounds: (0, 64))))",
                "s": "0x\(signature.substring(with: Range(uncheckedBounds: (64, 128))))",
                "networkId": server.chainID.description,
                "contractAddress": signedOrder.order.contractAddress
            ])
        }
    }

    private struct CheckIfLinkClaimedRequest: URLRequestConvertible {
        let r: String

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.paymentServerBaseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/checkIfSignatureIsUsed"

            var request = try URLRequest(url: components.asURL(), method: .get)

            return try URLEncoding().encode(request, with: [
                "r": r
            ])
        }
    }
    
    private struct CheckPaymentServerSupportsContractRequest: URLRequestConvertible {
        let contractAddress: AlphaWallet.Address

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.paymentServerBaseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/checkContractIsSupportedForFreeTransfers"

            var request = try URLRequest(url: components.asURL(), method: .get)

            return try URLEncoding().encode(request, with: [
                "contractAddress": contractAddress.eip55String
            ])
        }
    }
}
