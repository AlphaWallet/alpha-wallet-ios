// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct ConfigureTransactionViewModel {
    enum RecoveryMode {
        case invalidNonce
        case none
    }

    private let ethPrice: Subscribable<Double>
    private let transactionType: TransactionType
    private let configurator: TransactionConfigurator
    private let fullFormatter = EtherNumberFormatter.full
    private var totalFee: BigInt {
        return configurationToEdit.gasPrice * configurationToEdit.gasLimit
    }
    private var server: RPCServer {
        configurator.session.server
    }
    private var currencyRate: CurrencyRate? {
        configurator.session.balanceCoordinator.ethBalanceViewModel.currencyRate
    }

    var recoveryMode: RecoveryMode
    var selectedConfigurationType: TransactionConfigurationType
    var configurationToEdit: EditedTransactionConfiguration {
        didSet {
            configurations.custom = configurationToEdit.configuration
        }
    }
    var configurationTypes: [TransactionConfigurationType]
    var configurations: TransactionConfigurations {
        didSet {
            configurationTypes = ConfigureTransactionViewModel.sortedConfigurationTypes(fromConfigurations: configurations)
        }
    }
    var gasPriceWarning: TransactionConfigurator.GasPriceWarning? {
        configurator.gasPriceWarning(forConfiguration: configurationToEdit.configuration)
    }

    var gasLimitWarning: TransactionConfigurator.GasLimitWarning? {
        configurator.gasLimitWarning(forConfiguration: configurationToEdit.configuration)
    }

    var gasFeeWarning: TransactionConfigurator.GasFeeWarning? {
        configurator.gasFeeWarning(forConfiguration: configurationToEdit.configuration)
    }

    var gasViewModel: GasViewModel {
        return GasViewModel(fee: totalFee, symbol: server.symbol, currencyRate: currencyRate, formatter: fullFormatter)
    }

    var backgroundColor: UIColor {
        return R.color.alabaster()!
    }

    var title: String {
        return R.string.localizable.configureTransactionNavigationBarTitle()
    }

    var isDataInputHidden: Bool {
        switch transactionType {
        case .nativeCryptocurrency, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            return false
        case .erc20Token, .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token:
            return true
        }
    }

    var gasLimitSliderViewModel: SlidableTextFieldViewModel {
        return .init(
            value: configurationToEdit.gasLimitRawValue,
            minimumValue: configurationToEdit.defaultMinGasLimit,
            maximumValue: configurationToEdit.maxGasLimit
        )
    }

    var gasPriceSliderViewModel: SlidableTextFieldViewModel {
        return .init(
            value: configurationToEdit.gasPriceRawValue,
            minimumValue: configurationToEdit.defaultMinGasPrice,
            maximumValue: configurationToEdit.maxGasPrice
        )
    }

    var nonceViewModel: TextFieldViewViewModel {
        let placeholder = R.string.localizable.configureTransactionNonceLabelTitle()
        let value = configurationToEdit.nonceRawValue.flatMap { String($0) }

        return .init(placeholder: placeholder, value: value ?? "", keyboardType: .numberPad)
    }

    var dataViewModel: TextFieldViewViewModel {
        let placeholder = R.string.localizable.configureTransactionDataLabelTitle()

        return .init(placeholder: placeholder, value: configurationToEdit.dataRawValue)
    }

    var totalFeeViewModel: TextFieldViewViewModel {
        let placeholder = R.string.localizable.configureTransactionTotalNetworkFeeLabelTitle()

        return .init(placeholder: placeholder, value: gasViewModel.feeText, allowEditing: false)
    }

    var sections: [Section] {
        switch selectedConfigurationType {
        case .standard, .slow, .fast, .rapid:
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

    init(configurator: TransactionConfigurator, ethPrice: Subscribable<Double>, recoveryMode: ConfigureTransactionViewModel.RecoveryMode) {
        self.ethPrice = ethPrice
        let configurations = configurator.configurations
        self.configurationTypes = ConfigureTransactionViewModel.sortedConfigurationTypes(fromConfigurations: configurations)
        self.configurator = configurator
        self.configurations = configurations
        transactionType = configurator.transaction.transactionType
        self.recoveryMode = recoveryMode
        switch recoveryMode {
        case .invalidNonce:
            selectedConfigurationType = .custom
        case .none:
            selectedConfigurationType = configurator.selectedConfigurationType
        }
        configurationToEdit = EditedTransactionConfiguration(configuration: configurator.configurations.custom)
    }

    static func sortedConfigurationTypes(fromConfigurations configurations: TransactionConfigurations) -> [TransactionConfigurationType] {
        let available = configurations.types
        let all: [TransactionConfigurationType] = [.slow, .standard, .fast, .rapid, .custom]
        return all.filter { available.contains($0) }
    }

    func gasSpeedViewModel(indexPath: IndexPath) -> GasSpeedViewModel {
        let configurationType = configurationTypes[indexPath.row]
        let isSelected = selectedConfigurationType == configurationType
        let configuration = configurations[configurationType]!
        //TODO if subscribable price are resolved or changes, will be good to refresh, but not essential
        return .init(configuration: configuration, configurationType: configurationType, cryptoToDollarRate: ethPrice.value, symbol: server.symbol, title: configurationType.title, isSelected: isSelected)
    }

    func gasSpeedViewModel(configurationType: TransactionConfigurationType) -> GasSpeedViewModel {
        let isSelected = selectedConfigurationType == configurationType
        let configuration = configurations[configurationType]!
        //TODO if subscribable price are resolved or changes, will be good to refresh, but not essential
        return .init(configuration: configuration, configurationType: configurationType, cryptoToDollarRate: ethPrice.value, symbol: server.symbol, title: configurationType.title, isSelected: isSelected)
    }

    func numberOfRowsInSections(in section: Int) -> Int {
        switch sections[section] {
        case .configurationTypes:
            return configurationTypes.count
        case .gasPrice:
            return 1
        case .gasLimit:
            return gasLimitRows.count
        }
    }

    var indexPaths: [IndexPath] {
        return sections.indices.map { section -> [IndexPath] in
            guard numberOfRowsInSections(in: section) > 0 else { return [] }
            return (0 ..< numberOfRowsInSections(in: section)).map { row in
                IndexPath(row: row, section: section)
            }
        }.flatMap { $0 }
    }
}
