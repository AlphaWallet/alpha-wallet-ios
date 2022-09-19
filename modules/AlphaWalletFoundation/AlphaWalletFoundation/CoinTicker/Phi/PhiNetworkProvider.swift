//
//  PhiNetworkProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 16.09.2022.
//

import Foundation
import Alamofire
import Combine
import AlphaWalletCore
import SwiftyJSON

struct PhiNetworkProvider: CoinTickerNetworkProviderType {

    func fetchSupportedTickerIds() -> AnyPublisher<[TickerId], PromiseError> {
        return .empty()
    }

    public func fetchTickers(for tickerIds: [TickerIdString], currency: String) -> AnyPublisher<[CoinTicker], PromiseError> {
        let publishers = Set(tickerIds).map { coinTicker(tickerId: $0, currency: currency).replaceError(with: nil) }
        return Publishers.MergeMany(publishers).collect()
            .setFailureType(to: PromiseError.self)
            .map { $0.compactMap { $0 } }
            .eraseToAnyPublisher()
    }

    func fetchChartHistory(for period: ChartHistoryPeriod, tickerId: String, currency: String) -> AnyPublisher<ChartHistory, PromiseError> {
        return .empty()
    }

    private func coinTicker(tickerId: String, currency: String) -> AnyPublisher<CoinTicker?, PromiseError> {
        Alamofire.request(CoinTickerRequest(tickerId: tickerId))
            .responseDataPublisher()
            .tryMap { PhiTicker(json: try JSON(data: $0.data), tickerId: tickerId, currency: currency) }
            .mapError { PromiseError(error: $0) }
            .map { $0.flatMap { CoinTicker(phiTicker: $0, id: tickerId) } }
            .share() 
            .eraseToAnyPublisher()
    }
}

extension PhiNetworkProvider {
    private struct CoinTickerRequest: URLRequestConvertible {
        let tickerId: String

        func asURLRequest() throws -> URLRequest {
            guard var components = URLComponents(url: Constants.Phi.baseUrl, resolvingAgainstBaseURL: false) else { throw URLError(.badURL) }
            components.path = "/api/ticker"

            return try URLEncoding().encode(URLRequest(url: components.asURL(), method: .get), with: ["filter": "\(tickerId)"])
        }
    }
}
