// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Alamofire

public class EtherscanGasPriceEstimator {
    struct EtherscanPriceEstimatesResponse: Decodable {
        let result: EtherscanPriceEstimates
    }

    static func supports(server: RPCServer) -> Bool {
        return server.etherscanGasPriceEstimatesURL != nil
    }

    public func fetch(server: RPCServer) -> Promise<GasPriceEstimates> {
        struct AnyError: Error {}
        guard let url = server.etherscanGasPriceEstimatesURL else {
            return .init(error: AnyError())
        }

        return Alamofire.request(url, method: .get).responseDecodable(EtherscanPriceEstimatesResponse.self).compactMap { response in
            EtherscanPriceEstimates.bridgeToGasPriceEstimates(for: response.result)
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
