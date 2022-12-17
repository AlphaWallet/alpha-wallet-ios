// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import SwiftyJSON
import Combine
import AlphaWalletCore

public class BlockscanChat {
    private var lastKnownCount: Int?
    private let networkService: NetworkService

    let address: AlphaWallet.Address

    public init(networkService: NetworkService, address: AlphaWallet.Address) {
        self.address = address
        self.networkService = networkService
    }

    public func fetchUnreadCount() -> AnyPublisher<Int, PromiseError> {
        infoLog("[BlockscanChat] Fetching unread count for \(address.eip55String)…")
        return networkService
            .dataTaskPublisher(GetUnreadCountEndpointRequest(address: address))
            .tryMap { return try JSON(data: $0.data)["result"].intValue }
            .handleEvents(receiveOutput: { [weak self, address] in
                self?.lastKnownCount = $0
                infoLog("[BlockscanChat] Fetched unread count for \(address.eip55String) count: \($0)")
            })
            .mapError { PromiseError.some(error: $0) }
            .eraseToAnyPublisher()
    }
}

extension BlockscanChat {
    struct GetUnreadCountEndpointRequest: URLRequestConvertible {
        let address: AlphaWallet.Address

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.BlockscanChat.unreadCountBaseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/blockscanchat/unreadcount/\(address.eip55String)"
            var request = try URLRequest(url: components.asURL(), method: .get)

            return request.appending(httpHeaders: ["PROXY_KEY": Constants.Credentials.blockscanChatProxyKey])
        }
    }
}
