// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import AlphaWalletFoundation

struct ConfigureTransactionViewModel {
    enum RecoveryMode {
        case invalidNonce
        case none
    }
    private let service: TokensProcessingPipeline
    private let transactionType: TransactionType
    let configurator: TransactionConfigurator
    private var totalFee: BigUInt {
        return configurationToEdit.gasPrice * configurationToEdit.gasLimit
    }
    private var server: RPCServer {
        configurator.session.server
    }
    private var coinTicker: CoinTicker? {
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: configurator.session.server)
        return service.tokenViewModel(for: etherToken)?.balance.ticker
    }

    var recoveryMode: RecoveryMode
    var selectedGasSpeed: GasSpeed
    var configurationToEdit: EditedTransactionConfiguration {
        didSet {
            configurations.custom = configurationToEdit.configuration
        }
    }
    var gasSpeedsList: [GasSpeed]
    var configurations: TransactionConfigurations {
        didSet {
            gasSpeedsList = ConfigureTransactionViewModel.sortedGasSpeedList(fromConfigurations: configurations)
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
        let rate = coinTicker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) }
        return GasViewModel(fee: totalFee, symbol: server.symbol, rate: rate, formatter: EtherNumberFormatter.full)
    }

    var title: String {
        return R.string.localizable.configureTransactionNavigationBarTitle()
    }

    var isDataInputHidden: Bool {
        switch transactionType {
        case .nativeCryptocurrency, .prebuilt:
            return false
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
            return true
        }
    }

    var gasLimitSliderViewModel: SlidableTextFieldViewModel {
        return .init(
            value: configurationToEdit.gasLimitRawValue,
            minimumValue: configurationToEdit.defaultMinGasLimit,
            maximumValue: configurationToEdit.maxGasLimit)
    }

    var gasPriceSliderViewModel: SlidableTextFieldViewModel {
        return .init(
            value: configurationToEdit.gasPriceRawValue,
            minimumValue: configurationToEdit.defaultMinGasPrice,
            maximumValue: configurationToEdit.maxGasPrice)
    }

    var nonceViewModel: TextFieldViewModel {
        let placeholder = R.string.localizable.configureTransactionNonceLabelTitle()
        let value = configurationToEdit.nonceRawValue.flatMap { String($0) }

        return .init(placeholder: placeholder, value: value ?? "", keyboardType: .numberPad)
    }

    var dataViewModel: TextFieldViewModel {
        let placeholder = R.string.localizable.configureTransactionDataLabelTitle()

        return .init(placeholder: placeholder, value: configurationToEdit.dataRawValue)
    }

    var totalFeeViewModel: TextFieldViewModel {
        let placeholder = R.string.localizable.configureTransactionTotalNetworkFeeLabelTitle()

        return .init(placeholder: placeholder, value: gasViewModel.feeText, allowEditing: false)
    }

    var sections: [Section] {
        switch selectedGasSpeed {
        case .standard, .slow, .fast, .rapid:
            return [.configurations]
        case .custom:
            return [.configurations, .custom]
        }
    }

    var editableConfigurationViews: [ConfigureTransactionViewModel.ViewType] {
        var views: [ConfigureTransactionViewModel.ViewType] = [
            .header(string: R.string.localizable.configureTransactionHeaderGasPrice()), .field(.gasPrice),
            .header(string: R.string.localizable.configureTransactionHeaderGasLimit()), .field(.gasLimit),
            .field(.nonce)
        ]

        if !isDataInputHidden {
            views += [.field(.transactionData)]
        }

        views += [.field(.totalFee)]
        
        return views
    }

    init(configurator: TransactionConfigurator,
         recoveryMode: ConfigureTransactionViewModel.RecoveryMode,
         service: TokensProcessingPipeline) {
        
        let configurations = configurator.configurations
        self.gasSpeedsList = ConfigureTransactionViewModel.sortedGasSpeedList(fromConfigurations: configurations)
        self.configurator = configurator
        self.configurations = configurations
        self.transactionType = configurator.transaction.transactionType
        self.recoveryMode = recoveryMode
        self.service = service
        switch recoveryMode {
        case .invalidNonce:
            selectedGasSpeed = .custom
        case .none:
            selectedGasSpeed = configurator.selectedGasSpeed
        }
        configurationToEdit = EditedTransactionConfiguration(configuration: configurator.configurations.custom, server: configurator.session.server)
    }

    static func sortedGasSpeedList(fromConfigurations configurations: TransactionConfigurations) -> [GasSpeed] {
        let available = configurations.types
        let all: [GasSpeed] = [.slow, .standard, .fast, .rapid, .custom]
        return all.filter { available.contains($0) }
    }

    func gasSpeedViewModel(gasSpeed: GasSpeed) -> GasSpeedViewModelType {
        let isSelected = selectedGasSpeed == gasSpeed
        let configuration = configurations[gasSpeed]!
        //TODO if subscribable price are resolved or changes, will be good to refresh, but not essential
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: configurator.session.server)
        let rate = service.tokenViewModel(for: etherToken)?.balance.ticker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) }

        return LegacyGasSpeedViewModel(
            gasPrice: configuration.gasPrice,
            gasLimit: configuration.gasLimit,
            gasSpeed: gasSpeed,
            rate: rate,
            symbol: server.symbol,
            isSelected: isSelected)
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
