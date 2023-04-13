//
//  EditTransactionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.04.2023.
//

import Foundation
import Combine
import AlphaWalletFoundation
import BigInt

struct EditTransactionViewModelInput {

}

struct EditTransactionViewModelOutput {
    let gasLimitHeader: AnyPublisher<String, Never>
    let isDataFieldHidden: AnyPublisher<Bool, Never>
}

class EditTransactionViewModel {
    private let service: TokensProcessingPipeline
    private let configurator: TransactionConfigurator
    private var server: RPCServer { configurator.session.server }
    private let recoveryMode: RecoveryMode
    private var isDataInputHidden: Bool {
        switch configurator.transaction.transactionType {
        case .nativeCryptocurrency, .prebuilt:
            return false
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
            return true
        }
    }
    private var cancellable = Set<AnyCancellable>()

    lazy var gasLimitSliderViewModel: SlidableTextFieldViewModel = {
        return SlidableTextFieldViewModel(
            value: (Decimal(bigUInt: configurator.gasLimit.value, decimals: 0) ?? .zero).doubleValue,
            minimumValue: (Decimal(bigUInt: GasLimitConfiguration.minGasLimit, decimals: 0) ?? .zero).doubleValue,
            maximumValue: (Decimal(bigUInt: GasLimitConfiguration.maxGasLimit(forServer: server), decimals: 0) ?? .zero).doubleValue)
    }()

    lazy var nonceViewModel: TextFieldViewModel = {
        let viewModel = TextFieldViewModel(text: configurator.nonce.flatMap { String($0) } ?? "")
        viewModel.placeholder = R.string.localizable.configureTransactionNonceLabelTitle()
        viewModel.keyboardType = .numberPad

        return viewModel
    }()

    lazy var dataViewModel: TextFieldViewModel = {
        let viewModel = TextFieldViewModel(text: configurator.data.hexEncoded.add0x)
        viewModel.placeholder = R.string.localizable.configureTransactionDataLabelTitle()

        return viewModel
    }()

    lazy var totalFeeViewModel: TextFieldViewModel = {
        let viewModel = TextFieldViewModel()
        viewModel.allowEditing = false
        viewModel.placeholder = R.string.localizable.configureTransactionTotalNetworkFeeLabelTitle()

        return viewModel
    }()

    @Published private (set) var gasLimit: BigUInt = BigUInt()
    @Published private (set) var totalFee: BigUInt = BigUInt()
    @Published private (set) var nonce: Int?
    @Published private (set) var data: Data = Data()

    let gasPriceViewModel: EditGasPriceViewModel

    init(configurator: TransactionConfigurator,
         recoveryMode: EditTransactionViewModel.RecoveryMode,
         service: TokensProcessingPipeline,
         gasPriceViewModel: EditGasPriceViewModel) {

        self.configurator = configurator
        self.recoveryMode = recoveryMode
        self.service = service
        self.gasPriceViewModel = gasPriceViewModel
    }

    func transform(input: EditTransactionViewModelInput) -> EditTransactionViewModelOutput {
        let gasLimit = gasLimitSliderViewModel.$value
            .map { Decimal($0).toBigUInt(decimals: 0) ?? BigUInt() }

        let nonce = nonceViewModel.$text
            .map { $0.flatMap { Int($0) } }

        let data = dataViewModel.$text
            .map { text -> Data in
                guard let text = text else { return Data() }
                return text.trimmed.isEmpty ? Data() : Data(hex: text.trimmed.drop0x)
            }

        let totalFee = Publishers.CombineLatest(gasPriceViewModel.gasPricePublisher, gasLimit)
            .map { $0.value.max * $1 }

        totalFee.assign(to: \.totalFee, on: self, ownership: .weak)
            .store(in: &cancellable)

        data.assign(to: \.data, on: self, ownership: .weak)
            .store(in: &cancellable)

        gasLimit.assign(to: \.gasLimit, on: self, ownership: .weak)
            .store(in: &cancellable)

        nonce.assign(to: \.nonce, on: self, ownership: .weak)
            .store(in: &cancellable)

        totalFee
            .compactMap { [weak self] in self?.validate(totalFee: $0) }
            .assign(to: \.status, on: totalFeeViewModel, ownership: .weak)
            .store(in: &cancellable)

        gasLimit
            .compactMap { [weak self] in self?.validate(gasLimit: $0) }
            .assign(to: \.status, on: gasLimitSliderViewModel, ownership: .weak)
            .store(in: &cancellable)

        nonce.compactMap { [weak self] in self?.makeNonceInvalidForRecoveryMode() ?? self?.validate(nonce: $0) }
            .assign(to: \.status, on: nonceViewModel, ownership: .weak)
            .store(in: &cancellable)

        let etherCurrencyRate = etherCurrencyRate()

        Publishers.CombineLatest(totalFee, etherCurrencyRate)
            .map { [server] in return GasViewModel(fee: $0, symbol: server.symbol, rate: $1, formatter: EtherNumberFormatter.full) }
            .sink { [weak totalFeeViewModel] in totalFeeViewModel?.set(text: $0.feeText) }
            .store(in: &cancellable)

        handleConfiguratorUpdates()

        return .init(
            gasLimitHeader: Just(R.string.localizable.configureTransactionHeaderGasLimit()).eraseToAnyPublisher(),
            isDataFieldHidden: Just(isDataInputHidden).eraseToAnyPublisher())
    }

    func save() -> Bool {
        guard isValid(gasLimit: gasLimit) else { return false }
        guard gasPriceViewModel.gasPrice.errors.isEmpty else { return false }
        guard isValid(nonce: nonce) else { return false }
        guard isValid(totalFee: totalFee) else { return false }

        configurator.set(customData: data)
        configurator.set(customNonce: nonce)
        configurator.set(customGasLimit: gasLimit)
        gasPriceViewModel.save()

        return true
    }

    private func etherCurrencyRate() -> AnyPublisher<CurrencyRate?, Never> {
        let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        return service.tokenViewModelPublisher(for: etherToken)
            .map { $0?.balance.ticker }
            .map { $0.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) } }
            .eraseToAnyPublisher()
    }

    private func handleConfiguratorUpdates() {
        configurator.$gasLimit
            .map { Decimal(bigUInt: $0.value, decimals: 0, fallback: .zero).doubleValue }
            .sink { [weak gasLimitSliderViewModel] in gasLimitSliderViewModel?.set(value: $0) }
            .store(in: &cancellable)

        configurator.$nonce
            .map { $0.flatMap { String($0) } ?? "" }
            .sink { [weak nonceViewModel] in nonceViewModel?.set(text: $0) }
            .store(in: &cancellable)
    }

    private func isValid(gasLimit: BigUInt) -> Bool {
        return gasLimit <= ConfigureTransaction.gasLimitMax && gasLimit >= 0
    }

    private func validate(gasLimit: BigUInt) -> TextField.TextFieldErrorState {
        guard isValid(gasLimit: gasLimit) else {
            return .error(ConfigureTransactionError.gasLimitTooHigh.localizedDescription)
        }
        if let warning = gasLimitWarning(gasLimit: gasLimit) {
            return .error(warning.description)
        }

        return .none
    }

    private func gasLimitWarning(gasLimit: BigUInt) -> TransactionConfigurator.GasLimitWarning? {
        if gasLimit > ConfigureTransaction.gasLimitMax {
            return .tooHighCustomGasLimit
        }
        return nil
    }

    private func isValid(totalFee: BigUInt) -> Bool {
        return totalFee <= ConfigureTransaction.gasFeeMax && totalFee >= 0
    }

    private func validate(totalFee: BigUInt) -> TextField.TextFieldErrorState {
        guard isValid(totalFee: totalFee) else {
            return .error(ConfigureTransactionError.gasFeeTooHigh.localizedDescription)
        }

        if let warning = gasFeeWarning(gasLimit: gasLimit) {
            return .error(warning.description)
        }

        return .none
    }

    public func gasFeeWarning(gasLimit: BigUInt) -> TransactionConfigurator.GasFeeWarning? {
        if (gasPriceViewModel.gasPrice.value.max * gasLimit) > ConfigureTransaction.gasFeeMax {
            return .tooHighGasFee
        }
        return nil
    }

    private func makeNonceInvalidForRecoveryMode() -> TextField.TextFieldErrorState? {
        switch recoveryMode {
        case .invalidNonce:
            return .error(ConfigureTransactionError.leaveNonceEmpty.localizedDescription)
        case .none:
            return nil
        }
    }

    private func isValid(nonce: Int?) -> Bool {
        guard let nonce = nonce else { return true }
        return nonce >= 0
    }

    private func validate(nonce: Int?) -> TextField.TextFieldErrorState {
        return isValid(nonce: nonce) ? .none : .error(ConfigureTransactionError.nonceNotPositiveNumber.localizedDescription)
    }

}

extension EditTransactionViewModel {
    enum RecoveryMode {
        case invalidNonce
        case none
    }
}

extension Decimal {
    init?(float: Float) {
        guard !float.isNaN && !float.isInfinite else { return nil }
        self.init(Double(float))
    }
}
