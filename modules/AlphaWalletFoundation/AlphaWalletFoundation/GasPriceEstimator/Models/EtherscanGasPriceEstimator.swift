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
        switch self {
        case .main, .binance_smart_chain, .heco, .polygon:
            return etherscanApiRoot?.appendingQueryString("\("module=gastracker&action=gasoracle")\(apiKeyParameter)")
        case .artis_sigma1, .artis_tau1, .binance_smart_chain_testnet, .callisto, .poa, .sokol, .classic, .xDai, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .mumbai_testnet, .cronosTestnet, .custom, .arbitrum, .arbitrumRinkeby, .kovan, .ropsten, .rinkeby, .goerli, .optimistic, .optimisticKovan, .palm, .palmTestnet, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet, .candle:
            return nil
        }
    }
}
