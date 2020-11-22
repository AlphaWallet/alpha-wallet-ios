// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import PromiseKit

class GasNowGasPriceEstimator {
    func fetch() -> Promise<GasNowPriceEstimates> {
        Promise { seal in
            let alphaWalletProvider = AlphaWalletProviderFactory.makeProvider()
            alphaWalletProvider.request(.gasPriceEstimate) { result in
                switch result {
                case .success(let response):
                    do {
                        let estimates = try response.map(GasNowPriceEstimates.self)
                        seal.fulfill(estimates)
                    } catch {
                        seal.reject(error)
                    }
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}