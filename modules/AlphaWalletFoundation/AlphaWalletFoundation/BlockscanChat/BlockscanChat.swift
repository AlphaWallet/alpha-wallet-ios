// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import SwiftyJSON
import Combine
import AlphaWalletCore

public class BlockscanChat {
    private var lastKnownCount: Int?
    private let networkService: NetworkService

    let address: AlphaWallet.Address

    public enum ResponseError: Error {
        case statusCode(Int)
        case other(Error)
    }

    public init(networkService: NetworkService, address: AlphaWallet.Address) {
        self.address = address
        self.networkService = networkService
    }

    public func fetchUnreadCount() -> AnyPublisher<Int, BlockscanChat.ResponseError> {
        infoLog("[BlockscanChat] Fetching unread count for \(address.eip55String)…")
        return networkService
            .dataTaskPublisher(GetUnreadCountEndpointRequest(address: address))
            .mapError { BlockscanChat.ResponseError.other($0) }
            .flatMap { response -> AnyPublisher<Int, BlockscanChat.ResponseError> in
                do {
                    let json = try JSON(data: response.data)
                    return .just(json["result"].intValue)
                } catch {
                    return .fail(.statusCode(response.response.statusCode))
                }
            }.handleEvents(receiveOutput: { [weak self, address] in
                self?.lastKnownCount = $0
                infoLog("[BlockscanChat] Fetched unread count for \(address.eip55String) count: \($0)")
            })
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}

extension BlockscanChat {
    struct GetUnreadCountEndpointRequest: URLRequestConvertible {
        let address: AlphaWallet.Address

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.BlockscanChat.unreadCountBaseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/blockscanchat/unreadcount/\(address.eip55String)"
            
            return try URLRequest(url: components.asURL(), method: .get, headers: [
                "PROXY_KEY": Constants.Credentials.blockscanChatProxyKey
            ])
        }
    }
}
