// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct EditedTransactionConfiguration {
    private let formatter = EtherNumberFormatter.full

    var gasPrice: BigInt {
        return formatter.number(from: String(gasPriceRawValue), units: UnitConfiguration.gasPriceUnit) ?? BigInt()
    }

    var gasLimit: BigInt {
        BigInt(String(gasLimitRawValue), radix: 10) ?? BigInt()
    }

    var data: Data {
        if dataRawValue.isEmpty {
            return .init()
        } else {
            return .init(hex: dataRawValue.drop0x)
        }
    }

    var gasPriceRawValue: Int
    var gasLimitRawValue: Int
    var dataRawValue: String
    var nonceRawValue: Int?

    var overridenMaxGasPrice: Int?
    var overridenMaxGasLimit: Int?

    let defaultMinGasLimit = Int(GasLimitConfiguration.minGasLimit)
    let defaultMinGasPrice = Int(GasPriceConfiguration.minPrice / BigInt(UnitConfiguration.gasPriceUnit.rawValue))

    private let defaultMaxGasLimit: Int = Int(GasLimitConfiguration.maxGasLimit)
    private let defaultMaxGasPrice: Int = Int(GasPriceConfiguration.maxPrice / BigInt(UnitConfiguration.gasPriceUnit.rawValue))

    var maxGasPrice: Int {
        if let overridenValue = overridenMaxGasPrice {
            return overridenValue
        } else {
            return defaultMaxGasPrice
        }
    }

    var maxGasLimit: Int {
        if let overridenValue = overridenMaxGasLimit {
            return overridenValue
        } else {
            return defaultMaxGasLimit
        }
    }

    mutating func updateMaxGasLimitIfNeeded(_ value: Int) {
        if value > defaultMaxGasLimit {
            overridenMaxGasLimit = value
        } else if value < defaultMinGasLimit {
            overridenMaxGasLimit = nil
        }
    }

    mutating func updateMaxGasPriceIfNeeded(_ value: Int) {
        if value > defaultMaxGasPrice {
            overridenMaxGasPrice = value
        } else if value < defaultMaxGasPrice {
            overridenMaxGasPrice = nil
        }
    }

    init(configuration: TransactionConfiguration) {
        gasLimitRawValue = Int(configuration.gasLimit.description) ?? 21000
        gasPriceRawValue = formatter.string(from: configuration.gasPrice, units: UnitConfiguration.gasPriceUnit).numberValue?.intValue ?? 1
        nonceRawValue = Int(configuration.nonce.flatMap { String($0) } ?? "")
        dataRawValue = configuration.data.hexEncoded.add0x

        updateMaxGasLimitIfNeeded(gasLimitRawValue)
        updateMaxGasPriceIfNeeded(gasPriceRawValue)
    }

    var configuration: TransactionConfiguration {
        return .init(gasPrice: gasPrice, gasLimit: gasLimit, data: data, nonce: nonceRawValue)
    }

    var isGasPriceValid: Bool {
        return gasPrice >= 0
    }

    var isGasLimitValid: Bool {
        return gasLimit <= ConfigureTransaction.gasLimitMax && gasLimit >= 0
    }

    var totalFee: BigInt {
        return gasPrice * gasLimit
    }

    var isTotalFeeValid: Bool {
        return totalFee <= ConfigureTransaction.gasFeeMax && totalFee >= 0
    }

    var isNonceValid: Bool {
        guard let nonce = nonceRawValue else { return true }
        return nonce >= 0
    }
}

struct ConfigureTransactionViewModel {
    var selectedConfigurationType: TransactionConfigurationType
    let server: RPCServer
    let transferType: TransferType
    var configurationToEdit: EditedTransactionConfiguration
    var configurationTypes: [TransactionConfigurationType] = [.default, .custom]
    let currencyRate: CurrencyRate?

    init(server: RPCServer, configurator: TransactionConfigurator, currencyRate: CurrencyRate?) {
        self.server = server
        self.currencyRate = currencyRate
        transferType = configurator.transaction.transferType
        selectedConfigurationType = configurator.selectedConfigurationType
        configurationToEdit = EditedTransactionConfiguration(configuration: configurator.customConfiguration)
    }

    private let fullFormatter = EtherNumberFormatter.full

    var gasViewModel: GasViewModel {
        return GasViewModel(fee: totalFee, symbol: server.symbol, currencyRate: currencyRate, formatter: fullFormatter)
    }

    private var totalFee: BigInt {
        return configurationToEdit.gasPrice * configurationToEdit.gasLimit
    }

    var backgroundColor: UIColor {
        return R.color.alabaster()!
    }

    var title: String {
        return R.string.localizable.configureTransactionNavigationBarTitle()
    }

    var isDataInputHidden: Bool {
        switch transferType {
        case .nativeCryptocurrency, .dapp, .tokenScript:
            return false
        case .ERC20Token, .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken:
            return true
        }
    }

    func gasSpeedViewModel(indexPath: IndexPath) -> GasSpeedTableViewCellViewModel {
        let configuration = configurationTypes[indexPath.row]
        let isSelected = selectedConfigurationType == configuration
        return .init(speed: configuration.title, estimatedTime: nil, details: nil, isSelected: isSelected)
    }

    var gasLimitSliderViewModel: SliderTableViewCellViewModel {
        return .init(
            value: configurationToEdit.gasLimitRawValue,
            minimumValue: configurationToEdit.defaultMinGasLimit,
            maximumValue: configurationToEdit.maxGasLimit
        )
    }

    var gasPriceSliderViewModel: SliderTableViewCellViewModel {
        return .init(
            value: configurationToEdit.gasPriceRawValue,
            minimumValue: configurationToEdit.defaultMinGasPrice,
            maximumValue: configurationToEdit.maxGasPrice
        )
    }

    var nonceViewModel: TextFieldTableViewCellViewModel {
        let placeholder = R.string.localizable.configureTransactionNonceLabelTitle()
        let value = configurationToEdit.nonceRawValue.flatMap { String($0) }

        return .init(placeholder: placeholder, value: value ?? "", keyboardType: .numberPad)
    }

    var dataViewModel: TextFieldTableViewCellViewModel {
        let placeholder = R.string.localizable.configureTransactionDataLabelTitle()

        return .init(placeholder: placeholder, value: configurationToEdit.dataRawValue)
    }

    var totalFeeViewModel: TextFieldTableViewCellViewModel {
        let placeholder = R.string.localizable.configureTransactionTotalNetworkFeeLabelTitle()

        return .init(placeholder: placeholder, value: gasViewModel.feeText, allowEditing: false)
    }

    func numberOfSections(in section: Int) -> Int {
        switch sections[section] {
        case .configurationTypes:
            return configurationTypes.count
        case .gasPrice:
            return 1
        case .gasLimit:
            return gasLimitRows.count
        }
    }

    var sections: [Section] {
        switch selectedConfigurationType {
        case .default:
            return [.configurationTypes]
        case .custom:
            return [.configurationTypes, .gasPrice, .gasLimit]
        }
    }

    var gasLimitRows: [GasLimit.Row] {
        if isDataInputHidden {
            return [.gasLimit, .nonce, .totalFee]
        } else {
            return [.gasLimit, .nonce, .transactionData, .totalFee]
        }
    }

    enum Section: Int, CaseIterable {
        case configurationTypes
        case gasPrice
        case gasLimit
    }

    var gasPriceHeaderTitle: String {
        return R.string.localizable.configureTransactionHeaderGasPrice()
    }

    var gasLimitHeaderTitle: String {
        return R.string.localizable.configureTransactionHeaderGasLimit()
    }

    enum GasLimit {
        enum Row: Int, CaseIterable {
            case gasLimit
            case nonce
            case transactionData
            case totalFee
        }
    }
}

private let numberValueFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")

    return formatter
}()

extension String {
    var numberValue: NSNumber? {
        return numberValueFormatter.number(from: self)
    }
}
