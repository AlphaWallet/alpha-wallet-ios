// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

struct GasPriceEstimates: Decodable {
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

extension EtherscanPriceEstimates {

    /// Current label in UI    Key to pull gas price from
    /// - Rapid    "FastGasPrice" * 1.2
    /// - Fast    "FastGasPrice"
    /// - Standard/Average    "ProposeGasPrice"
    /// - Slow    "SafeGasPrice"
    static func bridgeToGasPriceEstimates(for value: EtherscanPriceEstimates) -> GasPriceEstimates? {
        let _slow = EtherNumberFormatter.full.number(from: value.safeGasPrice, units: UnitConfiguration.gasPriceUnit)!
        let _standard = EtherNumberFormatter.full.number(from: value.proposeGasPrice, units: UnitConfiguration.gasPriceUnit)!
        let _fastGasPrice = EtherNumberFormatter.full.number(from: value.fastGasPrice, units: UnitConfiguration.gasPriceUnit)!

        guard let slow = Int(_slow.description), let standard = Int(_standard.description), let fast = Int(_fastGasPrice.description) else { return nil }
        let data = GasPriceEstimates.Data(slow: slow, standard: standard, fast: fast, rapid: Int((Double(fast) * 1.2).rounded(.down)))
        return GasPriceEstimates(data: data, code: 1)
    }
}

struct EtherscanPriceEstimates: Decodable {
    enum CodingKeys: String, CodingKey {
        case fastGasPrice = "FastGasPrice"
        case proposeGasPrice = "ProposeGasPrice"
        case safeGasPrice = "SafeGasPrice"
        case suggestBaseFee = "suggestBaseFee"
    }

    let fastGasPrice: String
    let proposeGasPrice: String
    let safeGasPrice: String
    let suggestBaseFee: String
}
