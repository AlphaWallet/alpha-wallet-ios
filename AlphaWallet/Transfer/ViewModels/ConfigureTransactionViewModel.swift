// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import AlphaWalletFoundation

struct ConfigureTransactionViewModel {
    enum RecoveryMode {
        case invalidNonce
        case none
    }
    private let service: TokenViewModelState
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
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: configurator.session.server)
        return service.tokenViewModel(for: etherToken)?.balance.ticker?.rate
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
        return configurator.gasPriceWarning(forConfiguration: configurationToEdit.configuration)
    }

    var gasLimitWarning: TransactionConfigurator.GasLimitWarning? {
        return configurator.gasLimitWarning(forConfiguration: configurationToEdit.configuration)
    }

    var gasFeeWarning: TransactionConfigurator.GasFeeWarning? {
        return configurator.gasFeeWarning(forConfiguration: configurationToEdit.configuration)
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
        case .nativeCryptocurrency, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
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
            return [.configurations]
        case .custom:
            return [.configurations, .custom]
        }
    }

    var editableConfigurationViews: [ConfigureTransactionViewModel.ViewType] {
        var views: [ConfigureTransactionViewModel.ViewType] = [
            .header(string: gasPriceHeaderTitle), .field(.gasPrice),
            .header(string: gasLimitHeaderTitle), .field(.gasLimit),
            .field(.nonce)
        ]

        if isDataInputHidden {
            views += [.field(.transactionData)]
        }

        views += [.field(.totalFee)]
        
        return views
    }

    var gasPriceHeaderTitle: String {
        return R.string.localizable.configureTransactionHeaderGasPrice()
    }

    var gasLimitHeaderTitle: String {
        return R.string.localizable.configureTransactionHeaderGasLimit()
    }

    init(configurator: TransactionConfigurator, recoveryMode: ConfigureTransactionViewModel.RecoveryMode, service: TokenViewModelState) {
        let configurations = configurator.configurations
        self.configurationTypes = ConfigureTransactionViewModel.sortedConfigurationTypes(fromConfigurations: configurations)
        self.configurator = configurator
        self.configurations = configurations
        self.transactionType = configurator.transaction.transactionType
        self.recoveryMode = recoveryMode
        self.service = service
        switch recoveryMode {
        case .invalidNonce:
            selectedConfigurationType = .custom
        case .none:
            selectedConfigurationType = configurator.selectedConfigurationType
        }
        configurationToEdit = EditedTransactionConfiguration(configuration: configurator.configurations.custom, server: configurator.session.server)
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
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: configurator.session.server)
        let ethPrice: Double? = service.tokenViewModel(for: etherToken)?.balance.ticker?.price_usd
        return .init(configuration: configuration, configurationType: configurationType, cryptoToDollarRate: ethPrice, symbol: server.symbol, title: configurationType.title, isSelected: isSelected)
    }

    func gasSpeedViewModel(configurationType: TransactionConfigurationType) -> GasSpeedViewModel {
        let isSelected = selectedConfigurationType == configurationType
        let configuration = configurations[configurationType]!
        //TODO if subscribable price are resolved or changes, will be good to refresh, but not essential
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: configurator.session.server)
        let ethPrice: Double? = service.tokenViewModel(for: etherToken)?.balance.ticker?.price_usd
        return .init(configuration: configuration, configurationType: configurationType, cryptoToDollarRate: ethPrice, symbol: server.symbol, title: configurationType.title, isSelected: isSelected)
    }

    func numberOfRowsInSections(in section: Int) -> Int {
        switch sections[section] {
        case .configurations:
            return configurationTypes.count
        case .custom:
            return editableConfigurationViews.count
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

extension ConfigureTransactionViewModel {

    enum Section: Int, CaseIterable {
        case configurations
        case custom
    }

    enum FieldType {
        case gasLimit
        case gasPrice
        case nonce
        case transactionData
        case totalFee
    }

    enum ViewType {
        case header(string: String)
        case field(FieldType)
    }

}
