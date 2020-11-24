// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

struct GasNowPriceEstimates: Decodable {
    struct Data: Decodable {
        let slow: Int
        let standard: Int
        let fast: Int
        let rapid: Int

        enum CodingKeys: String, CodingKey {
            case slow
            case fast
            case standard
            case rapid
        }
    }

    let data: Data
    let code: Int

    var slow: Int {
        data.slow
    }
    var fast: Int {
        data.fast
    }
    var standard: Int {
        data.standard
    }
    var rapid: Int {
        data.rapid
    }

    enum CodingKeys: String, CodingKey {
        case data
        case code
    }
}