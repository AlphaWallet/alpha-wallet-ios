// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import BigInt

class EtherscanGasPriceEstimator {
    private let networkService: NetworkService
    private let decoder = JSONDecoder()

    init(networkService: NetworkService) {
        self.networkService = networkService
    }

    static func supports(server: RPCServer) -> Bool {
        return server.etherscanGasPriceEstimatesURL != nil
    }

    func gasPriceEstimates(server: RPCServer) async throws -> GasEstimates {
        let response = try await networkService.dataTask(GetGasPriceEstimatesRequest(server: server))
        let result = try decoder.decode(EtherscanPriceEstimatesResponse.self, from: response.data)

        guard let estimates = EtherscanPriceEstimates.bridgeToGasPriceEstimates(for: result.result) else {
            throw CastError(actualValue: result.result, expectedType: GasPriceEstimates.self)
        }

        return GasEstimates(standard: BigUInt(estimates.standard), others: [
            TransactionConfigurationType.slow: BigUInt(estimates.slow),
            TransactionConfigurationType.fast: BigUInt(estimates.fast),
            TransactionConfigurationType.rapid: BigUInt(estimates.rapid)
        ])
    }
}

extension EtherscanGasPriceEstimator {
    struct EtherscanPriceEstimatesResponse: Decodable {
        let result: EtherscanPriceEstimates
    }

    struct GetGasPriceEstimatesRequest: URLRequestConvertible {
        let server: RPCServer

        func asURLRequest() throws -> URLRequest {
            guard let baseUrl = server.etherscanGasPriceEstimatesURL else { throw URLError(.badURL) }

            return try URLRequest(url: baseUrl, method: .get)
        }
    }
}

fileprivate extension RPCServer {
    var etherscanGasPriceEstimatesURL: URL? {
        let apiKeyParameter: String
        if let apiKey = etherscanApiKey {
            apiKeyParameter = "&apikey=\(apiKey)"
        } else {
            apiKeyParameter = ""
        }
        switch self.serverWithEnhancedSupport {
        case .main, .binance_smart_chain, .heco, .polygon:
            return etherscanApiRoot?.appendingQueryString("\("module=gastracker&action=gasoracle")\(apiKeyParameter)")
        case .xDai, .rinkeby, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, nil:
            return nil
        }
    }
}
