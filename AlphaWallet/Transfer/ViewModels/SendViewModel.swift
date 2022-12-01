// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation
import AlphaWalletCore
import Combine

struct SendViewModelInput {
    let cryptoValue: AnyPublisher<String, Never>
    let qrCode: AnyPublisher<String, Never>
    let allFunds: AnyPublisher<Void, Never>
    let send: AnyPublisher<Void, Never>
    let recipient: AnyPublisher<String, Never>
    let didAppear: AnyPublisher<Void, Never>
}

struct SendViewModelOutput {
    let viewState: AnyPublisher<SendViewModel.ViewState, Never>
    let scanQrCodeError: AnyPublisher<String, Never>
    let activateAmountInput: AnyPublisher<Void, Never>
    let token: AnyPublisher<Token?, Never>
    let cryptoErrorState: AnyPublisher<AmountTextField.ErrorState, Never>
    let allFundsAmount: AnyPublisher<(crypto: String, shortCrypto: String), Never>
    let recipientErrorState: AnyPublisher<TextField.TextFieldErrorState, Never>
    let confirmTransaction: AnyPublisher<UnconfirmedTransaction, Never>
}

/// suppots next transaction types: .nativeCryptocurrency, .erc20Token, .dapp, .claimPaidErc875MagicLink, .tokenScript, .prebuilt
final class SendViewModel {
    private let importToken: ImportToken
    private lazy var eip681UrlResolver = Eip681UrlResolver(config: session.config, importToken: importToken, missingRPCServerStrategy: .fallbackToPreffered(session.server))
    private let session: WalletSession
    private let tokensService: TokenProvidable & TokenAddable & TokenBalanceRefreshable & TokenViewModelState
    private let transactionTypeSubject: CurrentValueSubject<TransactionType, Never>
    private var cancelable = Set<AnyCancellable>()
    private (set) lazy var amountTextFieldViewModel = AmountTextFieldViewModel(token: token, debugName: "")
    private var cryptoValueString: String = ""
    private var cryptoValue: BigInt?
    private var recipient: AlphaWallet.Address?

    /// Returns token publisher for only supported transaction types
    private lazy var validToken: AnyPublisher<Token?, Never> = {
        return transactionTypeSubject.map { _ in return self.token }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }()

    /// TokenViewModel updates once we receive a new token, might be when scan qr code or initially. Ask to refresh token balance when received. Only for supported transaction types tokens
    private lazy var tokenViewModel: AnyPublisher<TokenViewModel?, Never> = {
        return validToken.flatMapLatest { [tokensService] token -> AnyPublisher<TokenViewModel?, Never> in
            guard let token = token else { return .just(nil) }

            tokensService.refreshBalance(updatePolicy: .token(token: token))

            return tokensService.tokenViewModelPublisher(for: token)
        }.share(replay: 1)
        .eraseToAnyPublisher()
    }()

    /// Supports cases: `.nativeCryptocurrency, .erc20Token, .dapp, .claimPaidErc875MagicLink, .tokenScript, .prebuilt`
    private var token: Token? {
        switch transactionType {
        case .nativeCryptocurrency:
            //NOTE: looks like we can use transactionType.tokenObject, for nativeCryptocurrency it might contains incorrect contract value
            return tokensService.token(for: transactionType.contract, server: session.server)
        case .erc20Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return transactionType.tokenObject
        case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
            return nil
        }
    }

    private var title: String {
        "\(R.string.localizable.send()) \(transactionType.symbol)"
    }

    private var transactionType: TransactionType {
        return transactionTypeSubject.value
    }

    var shortValueForAllFunds: String? {
        return amountTextFieldViewModel.isAllFunds ? allFundsFormattedValues?.allFundsShortValue : .none
    }

    let amountViewModel = SendViewSectionHeaderViewModel(text: R.string.localizable.sendAmount().uppercased(), showTopSeparatorLine: true)
    let recipientViewModel = SendViewSectionHeaderViewModel(text: R.string.localizable.sendRecipient().uppercased())
    let backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    init(transactionType: TransactionType, session: WalletSession, tokensService: TokenProvidable & TokenAddable & TokenBalanceRefreshable & TokenViewModelState, importToken: ImportToken) {
        self.importToken = importToken
        self.transactionTypeSubject = .init(transactionType)
        self.tokensService = tokensService
        self.session = session 
    }

    func transform(input: SendViewModelInput) -> SendViewModelOutput {
        input.cryptoValue
            .assign(to: \.cryptoValueString, on: self, ownership: .weak)
            .store(in: &cancelable)

        bigIntValue(cryptoValue: input.cryptoValue)
            .assign(to: \.cryptoValue, on: self, ownership: .weak)
            .store(in: &cancelable)

        resetAllFundsWhenTextChanged(for: input.cryptoValue)
            .assign(to: \.isAllFunds, on: amountTextFieldViewModel)
            .store(in: &cancelable)

        // Reload transaction type when balance has changed, out of cur logic
        updateTransactionTypeWhenViewModelHasChanged()
            .assign(to: \.value, on: transactionTypeSubject)
            .store(in: &cancelable)

        input.recipient
            .map { AlphaWallet.Address(string: $0) }
            .assign(to: \.recipient, on: self)
            .store(in: &cancelable)

        let confirmTransactionResult = transactionToConfirm(send: input.send)
        let confirmTransaction = confirmTransactionResult
            .compactMap { $0.value }
            .eraseToAnyPublisher()

        let inputsValidationError = confirmTransactionResult
            .map { $0.error }
            .eraseToAnyPublisher()

        let recipientErrorState = isRecipientValid(inputsValidationError: inputsValidationError)
            .map { $0 ? TextField.TextFieldErrorState.none : TextField.TextFieldErrorState.error(InputError.invalidAddress.prettyError) }
            .eraseToAnyPublisher()

        let cryptoErrorState = isCryptoValueValid(cryptoValue: input.cryptoValue, send: input.send)
            .map { $0 ? AmountTextField.ErrorState.none : AmountTextField.ErrorState.error }
            .eraseToAnyPublisher()

        let allFundsAmount = formattedAllFunds(for: input.allFunds)

        let scanQrCode = input.qrCode
            .flatMap { self.scanQrCode(from: $0, amount: self.cryptoValueString) }
            .handleEvents(receiveOutput: { [transactionTypeSubject] in
                if let value = $0.value {
                    transactionTypeSubject.value = value
                }
            }).share()

        let activateAmountInput = activateAmountInput(scanQrCode: scanQrCode.eraseToAnyPublisher(), didAppear: input.didAppear)

        let scanQrCodeError = scanQrCode
            .compactMap { SendViewModel.mapScanQrCodeError($0) }
            .eraseToAnyPublisher()

        let viewState = Publishers.CombineLatest(tokenViewModel, transactionTypeSubject)
            .map { self.buildViewState(tokenViewModel: $0, transactionType: $1) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, scanQrCodeError: scanQrCodeError, activateAmountInput: activateAmountInput, token: validToken, cryptoErrorState: cryptoErrorState, allFundsAmount: allFundsAmount, recipientErrorState: recipientErrorState, confirmTransaction: confirmTransaction)
    }

    private func buildViewState(tokenViewModel: TokenViewModel?, transactionType: TransactionType) -> SendViewModel.ViewState {
        let cryptoToFiatRate = tokenViewModel.flatMap { $0.balance.ticker.flatMap { NSDecimalNumber(value: $0.price_usd) } }

        let selectCurrencyButtonState = selectCurrencyButtonState(for: tokenViewModel, transactionType: transactionType)
        let amountStatuLabelState = SendViewModel.AmountStatuLabelState(text: availableLabelText, isHidden: availableTextHidden)
        let amountTextFieldState = amountTextFieldState(for: transactionType, cryptoToFiatRate: cryptoToFiatRate)
        let recipientTextFieldState = recipientTextFieldState(for: transactionType)

        return .init(title: title, selectCurrencyButtonState: selectCurrencyButtonState, amountStatusLabelState: amountStatuLabelState, amountTextFieldState: amountTextFieldState, recipientTextFieldState: recipientTextFieldState)
    }

    private func updateTransactionTypeWhenViewModelHasChanged() -> AnyPublisher<TransactionType, Never> {
        tokenViewModel.compactMap { [tokensService, transactionTypeSubject] tokenViewModel -> TransactionType? in
            guard let tokenViewModel = tokenViewModel else { return nil }
            guard let token = tokensService.token(for: tokenViewModel.contractAddress, server: tokenViewModel.server) else { return nil }

            switch transactionTypeSubject.value {
            case .nativeCryptocurrency(_, let recipient, let amount):
                return self.makeTransactionType(token: token, recipient: recipient, amount: amount)
            case .erc20Token(_, let recipient, let amount):
                let amount = amount.flatMap { EtherNumberFormatter.plain.number(from: $0, decimals: token.decimals) }
                return self.makeTransactionType(token: token, recipient: recipient, amount: amount)
            //NOTE: do we need to repeat `case .erc20Token(_, let recipient, let amount)` for cases `.dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt`?
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                return nil
            }
        }.eraseToAnyPublisher()
    }

    private func transactionToConfirm(send: AnyPublisher<Void, Never>) -> AnyPublisher<Result<UnconfirmedTransaction, InputsValidationError>, Never> {
        return send.withLatestFrom(tokenViewModel)
            .map { [transactionType] tokenViewModel -> Result<UnconfirmedTransaction, InputsValidationError> in
                guard let recipient = self.recipient else {
                    return .failure(InputsValidationError.recipientInvalid)
                }
                guard let value = self.validatedCryptoValue(self.cryptoValue, tokenViewModel: tokenViewModel, checkIfGreaterThanZero: self.checkIfGreaterThanZero) else {
                    return .failure(InputsValidationError.cryptoValueInvalid)
                }
                do {
                    switch transactionType {
                    case .nativeCryptocurrency, .dapp, .claimPaidErc875MagicLink, .tokenScript, .prebuilt:
                        return .success(try transactionType.buildSendNativeCryptocurrency(recipient: recipient, amount: BigUInt(value)))
                    case .erc20Token:
                        return .success(try transactionType.buildSendErc20Token(recipient: recipient, amount: BigUInt(value)))
                    case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
                        throw TransactionConfiguratorError.impossibleToBuildConfiguration
                    }
                } catch {
                    return .failure(.other(error))
                }
            }.share()
            .eraseToAnyPublisher()
    }

    //NOTE: not sure if we need to set `isAllFunds` to true if edited value quals to balance value
    private func resetAllFundsIfNeeded(ethCostRawValue: NSDecimalNumber?) -> Bool? {
        guard let allFunds = allFundsFormattedValues, allFunds.allFundsFullValue.localizedString.nonEmpty else { return nil }
        guard let value = allFunds.allFundsFullValue, ethCostRawValue != value else { return nil }

        return false
    }

    private func activateAmountInput(scanQrCode: AnyPublisher<Result<TransactionType, CheckEIP681Error>, Never>, didAppear: AnyPublisher<Void, Never>) -> AnyPublisher<Void, Never> {
        let whenScannedQrCode = scanQrCode
            .filter { $0.isSuccess }
            .mapToVoid()
            .eraseToAnyPublisher()

        return Publishers.Merge(whenScannedQrCode, didAppear)
            .eraseToAnyPublisher()
    }

    private func amountTextFieldState(for transactionType: TransactionType, cryptoToFiatRate: NSDecimalNumber?) -> AmountTextFieldState {
        let transactedAmount: String? = {
            switch transactionType {
            case .nativeCryptocurrency(_, _, let amount):
                return amount.flatMap { EtherNumberFormatter.plain.string(from: $0, units: .ether) }
            case .erc20Token(_, _, let amount):
                return amount
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                return nil
            }
        }()

        return AmountTextFieldState(amount: transactedAmount, cryptoToFiatRate: cryptoToFiatRate)
    }

    private func recipientTextFieldState(for transactionType: TransactionType) -> RecipientTextFieldState {
        switch transactionType {
        case .nativeCryptocurrency(_, let recipient, _):
            return RecipientTextFieldState(recipient: recipient.flatMap { $0.stringValue })
        case .erc20Token(_, let recipient, _):
            return RecipientTextFieldState(recipient: recipient.flatMap { $0.stringValue })
        case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return RecipientTextFieldState(recipient: nil)
        }
    }

    private func selectCurrencyButtonState(for tokenViewModel: TokenViewModel?, transactionType: TransactionType) -> SendViewModel.SelectCurrencyButtonState {
        let currencyButtonHidden: Bool = {
            switch transactionType {
            case .nativeCryptocurrency, .erc20Token:
                return false
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                return true
            }
        }()

        let selectCurrencyButtonHidden: Bool = {
            switch transactionType {
            case .nativeCryptocurrency, .erc20Token:
                guard let ticker = tokenViewModel?.balance.ticker, ticker.price_usd > 0 else {
                    return true
                }
                return false
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                return true
            }
        }()

        return .init(isHidden: currencyButtonHidden, expandIconHidden: selectCurrencyButtonHidden)
    }

    private var availableLabelText: String? {
        switch transactionType {
        case .nativeCryptocurrency:
            let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: transactionType.server)
            return tokensService.tokenViewModel(for: etherToken)
                .flatMap { return R.string.localizable.sendAvailable($0.balance.amountShort) }
        case .erc20Token(let token, _, _):
            return tokensService.tokenViewModel(for: token)
                .flatMap { R.string.localizable.sendAvailable("\($0.balance.amountShort) \(transactionType.symbol)") }
        case .dapp, .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return nil
        }
    }

    private var availableTextHidden: Bool {
        switch transactionType {
        case .nativeCryptocurrency:
            return false
        case .erc20Token(let token, _, _):
            return tokensService.tokenViewModel(for: token)?.balance == nil
        case .dapp, .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return true
        }
    }

    private var checkIfGreaterThanZero: Bool {
        switch transactionType {
        case .nativeCryptocurrency, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return false
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
            return true
        }
    }

    private var allFundsFormattedValues: (allFundsFullValue: NSDecimalNumber?, allFundsShortValue: String)? {
        switch transactionType {
        case .nativeCryptocurrency:
            let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: transactionType.server)
            guard let balance = tokensService.tokenViewModel(for: etherToken)?.balance else { return nil }
            let fullValue = EtherNumberFormatter.plain.string(from: balance.value, units: .ether).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: balance.value, units: .ether).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)
        case .erc20Token(let token, _, _):
            guard let balance = tokensService.tokenViewModel(for: token)?.balance else { return nil }
            let fullValue = EtherNumberFormatter.plain.string(from: balance.value, decimals: token.decimals).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: balance.value, decimals: token.decimals).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)
        case .dapp, .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return nil
        }
    }

    private func bigIntValue(cryptoValue: AnyPublisher<String, Never>) -> AnyPublisher<BigInt?, Never> {
        cryptoValue.map { self.parseEnteredAmount($0) }
            .eraseToAnyPublisher()
    }

    /// Resets all funds value when text has changed
    private func resetAllFundsWhenTextChanged(for trigger: AnyPublisher<String, Never>) -> AnyPublisher<Bool, Never> {
        trigger.receive(on: RunLoop.main)
            .mapToVoid()
            .filter { [amountTextFieldViewModel] _ in amountTextFieldViewModel.isAllFunds }
            .map { [amountTextFieldViewModel] _ in amountTextFieldViewModel.cryptoRawValue }
            .compactMap { self.resetAllFundsIfNeeded(ethCostRawValue: $0) }
            .eraseToAnyPublisher()
    }

    /// Returns crypto and short crypto values when all funds selected, sets all funds flag for `amountTextFieldViewModel`
    private func formattedAllFunds(for trigger: AnyPublisher<Void, Never>) -> AnyPublisher<(crypto: String, shortCrypto: String), Never> {
        trigger.compactMap { _ in self.allFundsFormattedValues }
            .handleEvents(receiveOutput: { [amountTextFieldViewModel] _ in amountTextFieldViewModel.isAllFunds = true })
            .map { (crypto: $0.allFundsFullValue.localizedString, shortCrypto: $0.allFundsShortValue) }
            .eraseToAnyPublisher()
    }

    /// Validates recipient when send selected
    private func isRecipientValid(inputsValidationError: AnyPublisher<InputsValidationError?, Never>) -> AnyPublisher<Bool, Never> {
        return inputsValidationError
            .map { error -> Bool in
                guard let error = error else { return true }
                return error != .recipientInvalid
            }.eraseToAnyPublisher()
    }

    /// Validates entered crypto amount when text changing or send has selected, see: `checkIfGreaterThanZero` returns result async
    private func isCryptoValueValid(cryptoValue: AnyPublisher<String, Never>, send: AnyPublisher<Void, Never>) -> AnyPublisher<Bool, Never> {
        let whenCryptoValueHasChanged = Publishers.CombineLatest(cryptoValue, tokenViewModel)
            .map { self.validatedCryptoValue(self.parseEnteredAmount($0), tokenViewModel: $1, checkIfGreaterThanZero: false) != nil }

        let whenSendSelected = send.withLatestFrom(tokenViewModel)
            .map { self.validatedCryptoValue(self.cryptoValue, tokenViewModel: $0, checkIfGreaterThanZero: self.checkIfGreaterThanZero) != nil }

        return Publishers.Merge(whenCryptoValueHasChanged, whenSendSelected)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private func parseEnteredAmount(_ amountString: String) -> BigInt? {
        switch transactionType {
        case .nativeCryptocurrency, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return EtherNumberFormatter.full.number(from: amountString, units: .ether)
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
            return EtherNumberFormatter.full.number(from: amountString, decimals: transactionType.tokenObject.decimals)
        }
    }

    private func validateRecipient(_ string: String) -> Bool {
        AlphaWallet.Address(string: string) != nil
    }

    private func validatedCryptoValue(_ value: BigInt?, tokenViewModel: TokenViewModel?, checkIfGreaterThanZero: Bool = true) -> BigInt? {
        guard let value = value, checkIfGreaterThanZero ? value > 0 : true else {
            return nil
        }

        switch transactionType {
        case .nativeCryptocurrency, .erc20Token:
            if let balance = tokenViewModel?.balance, balance.value < value {
                return nil
            }
        case .dapp, .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            break
        }

        return value
    }

    private func scanQrCode(from qrCode: String, amount: String) -> AnyPublisher<Result<TransactionType, CheckEIP681Error>, Never> {
        guard let url = URL(string: qrCode) else {
            return Fail(error: CheckEIP681Error.notEIP681)
                .mapToResult()
                .eraseToAnyPublisher()
        }

        return eip681UrlResolver.resolvePublisher(url: url)
            .flatMap { [session] result -> AnyPublisher<TransactionType, CheckEIP681Error> in
                switch result {
                case .transaction(let transactionType, let token):
                    guard token.server == session.server else {
                        return .fail(CheckEIP681Error.embeded(error: CheckAndFillEIP681DetailsError.serverNotMatches))
                    }
                    return .just(transactionType)
                case .address(let recipient):
                    guard let token = self.token else { return .fail(CheckEIP681Error.embeded(error: CheckAndFillEIP681DetailsError.tokenNotFound)) }
                    let amountAsIntWithDecimals = EtherNumberFormatter.plain.number(from: amount, decimals: token.decimals)

                    return .just(self.makeTransactionType(token: token, recipient: .address(recipient), amount: amountAsIntWithDecimals))
                }
            }.mapToResult()
            .eraseToAnyPublisher()
    }

    private func makeTransactionType(token: Token, recipient: AddressOrEnsName?, amount: BigInt?) -> TransactionType {
        let amount = amount.flatMap { EtherNumberFormatter.plain.string(from: $0, decimals: token.decimals) }
        let newTransactionType: TransactionType
        if let amount = amount, amount != "0" {
            newTransactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: amount)
        } else {
            switch transactionType {
            case .nativeCryptocurrency(_, _, let amount):
                newTransactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: amount.flatMap { EtherNumberFormatter().string(from: $0, units: .ether) })
            case .erc20Token(_, _, let amount):
                newTransactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: amount)
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                newTransactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: nil)
            }
        }

        return newTransactionType
    }

    private static func mapScanQrCodeError(_ result: Result<TransactionType, CheckEIP681Error>) -> String? {
        switch result.error {
        case .tokenTypeNotSupported: return "Token Not Supported"
        case .configurationInvalid, .contractInvalid, .parameterInvalid, .missingRpcServer, .notEIP681, .embeded, .none: return nil
        }
    }
}

extension SendViewModel {
    struct ViewState {
        let title: String
        let selectCurrencyButtonState: SendViewModel.SelectCurrencyButtonState
        let amountStatusLabelState: AmountStatuLabelState
        let amountTextFieldState: AmountTextFieldState
        let recipientTextFieldState: RecipientTextFieldState
    }

    struct SelectCurrencyButtonState {
        let isHidden: Bool
        let expandIconHidden: Bool
    }

    struct AmountStatuLabelState {
        let text: String?
        let isHidden: Bool
    }

    struct AmountTextFieldState {
        let amount: String?
        let cryptoToFiatRate: NSDecimalNumber?
    }

    struct RecipientTextFieldState {
        let recipient: String?
    }

    fileprivate enum CheckAndFillEIP681DetailsError: LocalizedError {
        case serverNotMatches
        case tokenNotFound

        var localizedDescription: String {
            switch self {
            case .serverNotMatches:
                return "Server Not Matches"
            case .tokenNotFound:
                return "Token Not Found"
            }
        }
    }

    fileprivate enum InputsValidationError: Error {
        case other(Error)
        case recipientInvalid
        case cryptoValueInvalid
    }
}

extension SendViewModel.InputsValidationError: Equatable {
    static func == (lhs: SendViewModel.InputsValidationError, rhs: SendViewModel.InputsValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.other, .other):
            return true
        case (.recipientInvalid, .recipientInvalid):
            return true
        case (.cryptoValueInvalid, .cryptoValueInvalid):
            return true
        case (.other, .cryptoValueInvalid), (.other, .recipientInvalid), (.recipientInvalid, .cryptoValueInvalid), (.recipientInvalid, .other), (.cryptoValueInvalid, .other), (.cryptoValueInvalid, .recipientInvalid):
            return false
        }
    }


}

extension Swift.Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }

    var error: Failure? {
        switch self {
        case .failure(let e): return e
        case .success: return nil
        }
    }

    var value: Success? {
        switch self {
        case .failure: return nil
        case .success(let value): return value
        }
    }
}
