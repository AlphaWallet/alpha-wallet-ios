//
//  CovalentNetworkProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2022.
//

import SwiftyJSON 
import Combine
import AlphaWalletCore

public extension Covalent {
    public enum CovalentError: Error {
        case jsonDecodeFailure
        case requestFailure(PromiseError)
        case sessionError(SessionTaskError)
    }
}

final class CovalentNetworkService {
    private let key = Constants.Credentials.covalentApiKey
    private let networkService: NetworkService
    private let walletAddress: AlphaWallet.Address
    private let server: RPCServer

    init(networkService: NetworkService, walletAddress: AlphaWallet.Address, server: RPCServer) {
        self.walletAddress = walletAddress
        self.server = server
        self.networkService = networkService
    }

    func transactions(page: Int? = nil, pageSize: Int = 5, blockSignedAtAsc: Bool = false) -> AnyPublisher<Covalent.TransactionsResponse, Covalent.CovalentError> {
        return networkService
            .dataTaskPublisher(Covalent.TransactionsRequest(walletAddress: walletAddress, server: server, page: page, pageSize: pageSize, apiKey: key, blockSignedAtAsc: blockSignedAtAsc))
            .receive(on: DispatchQueue.global())
            .tryMap { response -> Covalent.TransactionsResponse in
                guard let json = try? JSON(data: response.data) else { throw Covalent.CovalentError.jsonDecodeFailure }

                return try Covalent.TransactionsResponse(json: json)
            }.mapError { return Covalent.CovalentError.requestFailure(.some(error: $0)) }
            .eraseToAnyPublisher()
    }
}
