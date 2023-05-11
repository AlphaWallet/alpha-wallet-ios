//
//  AddCustomChainNetworking.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 16.12.2022.
//

import Combine
import AlphaWalletCore
import SwiftyJSON

class AddCustomChainNetworking {
    private let networkService: NetworkService

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    func checkExplorerType(_ customChain: WalletAddEthereumChainObject) -> AnyPublisher<RPCServer.EtherscanCompatibleType, AddCustomChainError> {
        guard let urlString = customChain.blockExplorerUrls?.first else {
            return .just(.unknown)
        }

        guard let url = EtherscanURLBuilder(host: urlString.url).buildWithTokennfttx() else {
            return .just(.unknown)
        }

        return networkService
            .dataTaskPublisher(UrlRequest(url: url))
            .receive(on: DispatchQueue.global())
            .tryMap {
                if let json = try? JSON($0.data) {
                    if json["result"].array != nil {
                        return RPCServer.EtherscanCompatibleType.etherscan
                    } else {
                        return RPCServer.EtherscanCompatibleType.blockscout
                    }
                } else {
                    return RPCServer.EtherscanCompatibleType.unknown
                }
            }.catch { _ -> AnyPublisher<RPCServer.EtherscanCompatibleType, AddCustomChainError> in
                return .just(.unknown)
            }.receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    /// Figure out if "api." prefix is needed
    func figureOutHostname(_ originalUrlString: String) -> AnyPublisher<String, AddCustomChainError> {
        if let isPrefixedWithApiDot = URL(string: originalUrlString)?.host?.hasPrefix("api."), isPrefixedWithApiDot {
            return .just(originalUrlString)
        }

        //TODO is it necessary to check if already have https/http?
        let urlString = originalUrlString
                .replacingOccurrences(of: "https://", with: "https://api.")
                .replacingOccurrences(of: "http://", with: "http://api.")

        //Careful to use `action=tokentx` and not `action=tokennfttx` because only the former works with both Etherscan and Blockscout
        guard let url = EtherscanURLBuilder(host: urlString).buildWithTokentx() else {
            return .fail(AddCustomChainError.invalidBlockchainExplorerUrl)
        }

        return isValidBlockchainExplorerApiRoot(url)
            .map { _ in urlString }
            .catch { _ -> AnyPublisher<String, AddCustomChainError> in
                guard let url = EtherscanURLBuilder(host: originalUrlString).buildWithTokentx() else {
                    return .fail(AddCustomChainError.invalidBlockchainExplorerUrl)
                }

                return self.isValidBlockchainExplorerApiRoot(url)
                    .map { _ in originalUrlString }
                    .eraseToAnyPublisher()
            }.eraseToAnyPublisher()
    }

    private func isValidBlockchainExplorerApiRoot(_ url: URL) -> AnyPublisher<Void, AddCustomChainError> {
        networkService
            .dataTaskPublisher(UrlRequest(url: url))
            .receive(on: DispatchQueue.global())
            .tryMap {
                if let json = try? JSON($0.data), json["result"].array != nil {
                    return
                } else {
                    throw AddCustomChainError.invalidBlockchainExplorerUrl
                }
            }.mapError { _ in AddCustomChainError.invalidBlockchainExplorerUrl }
            .share()
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

struct UrlRequest: URLRequestConvertible {
    let url: URL

    func asURLRequest() throws -> URLRequest {
        return try URLRequest(url: url, method: .get)
    }
}

extension AddCustomChainNetworking {
    private struct EtherscanURLBuilder {
        private let host: String

        init(host: String) {
            self.host = host
        }

        func build(parameters: [String: String]) -> URL? {
            guard var url = URL(string: host) else { return nil }
            url.appendPathComponent("api")

            guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
            urlComponents.queryItems = parameters.map { key, value -> URLQueryItem in
                URLQueryItem(name: key, value: value)
            }

            return urlComponents.url
        }

        /// "\(urlString)/api?module=account&action=tokennfttx&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
        func buildWithTokennfttx() -> URL? {
            build(parameters: EtherscanURLBuilder.withTokennfttxParameters)
        }

        /// "\(urlString)/api?module=account&action=tokentx&address=0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
        func buildWithTokentx() -> URL? {
            build(parameters: EtherscanURLBuilder.withTokentxParameters)
        }

        static var withTokennfttxParameters: [String: String] {
            return [
                "module": "account",
                "action": "tokennfttx",
                "address": "0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
            ]
        }

        static var withTokentxParameters: [String: String] {
            return [
                "module": "account",
                "action": "tokentx",
                "address": "0x007bEe82BDd9e866b2bd114780a47f2261C684E3"
            ]
        }
    }

}
