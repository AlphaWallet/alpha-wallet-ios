// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import Alamofire

class GasNowGasPriceEstimator {
    func fetch() -> Promise<GasNowPriceEstimates> {
        let alphaWalletProvider = AlphaWalletProviderFactory.makeProvider()
        return alphaWalletProvider.request(.gasPriceEstimate).map { response -> GasNowPriceEstimates in
            try response.map(GasNowPriceEstimates.self)
        }
    }
}

class EtherscanGasPriceEstimator {

    struct EtherscanPriceEstimatesResponse: Decodable {
        let result: EtherscanPriceEstimates
    }

    static func supports(server: RPCServer) -> Bool {
        return server.etherscanGasPriceEstimatesURL != nil
    }

    func fetch(server: RPCServer) -> Promise<GasNowPriceEstimates> {
        struct AnyError: Error {}
        guard let url = server.etherscanGasPriceEstimatesURL else {
            return .init(error: AnyError())
        }

        return Alamofire.request(url, method: .get).responseDecodable(EtherscanPriceEstimatesResponse.self).compactMap { response in
            EtherscanPriceEstimates.bridgeToGasNowPriceEstimates(for: response.result)
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
        switch self {
        case .main, .binance_smart_chain, .heco, .polygon:
            return etherscanApiRoot?.appendingQueryString("\("module=gastracker&action=gasoracle")\(apiKeyParameter)")
        case .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .callisto, .poa, .sokol, .classic, .xDai, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .mumbai_testnet, .cronosTestnet, .custom, .arbitrum, .kovan, .ropsten, .rinkeby, .goerli, .optimistic, .optimisticKovan:
            return nil
        }
    }
}
