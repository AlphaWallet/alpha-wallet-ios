// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation
import AlphaWalletCore
import Combine

struct SendViewModelInput {
    let amountToSend: AnyPublisher<AmountTextFieldViewModel.FungibleAmount, Never>
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
    let token: AnyPublisher<TokenViewModel?, Never>
    let cryptoErrorState: AnyPublisher<AmountTextField.ErrorState, Never>
    let amountTextFieldState: AnyPublisher<SendViewModel.AmountTextFieldState, Never>
    let recipientErrorState: AnyPublisher<TextField.TextFieldErrorState, Never>
    let confirmTransaction: AnyPublisher<UnconfirmedTransaction, Never>
}

extension TokenViewModel: EnterAmountSupportable {}
extension Token: EnterAmountSupportable {}

/// suppots next transaction types: .nativeCryptocurrency, .erc20Token, .prebuilt
final class SendViewModel: TransactionTypeSupportable {
    private let transactionTypeFromQrCode: TransactionTypeFromQrCode
    private let session: WalletSession
    private let tokensPipeline: TokensProcessingPipeline
    private let transactionTypeSubject: CurrentValueSubject<TransactionType, Never>
    private var cancelable = Set<AnyCancellable>()
    private (set) lazy var amountTextFieldViewModel = AmountTextFieldViewModel(token: nil, debugName: "")
    private (set) var amountToSend: FungibleAmount = .notSet
    private var recipient: AlphaWallet.Address?
    private let tokensService: TokensService
    /// TokenViewModel updates once we receive a new token, might be when scan qr code or initially. Ask to refresh token balance when received. Only for supported transaction types tokens
    private lazy var tokenViewModel: AnyPublisher<TokenViewModel?, Never> = {
        return transactionTypeSubject
            .flatMap { [tokensService] transactionType in
                asFuture {
                    switch transactionType {
                    case .nativeCryptocurrency:
                        //NOTE: looks like we can use transactionType.tokenObject, for nativeCryptocurrency it might contains incorrect contract value
                        return await tokensService.token(for: transactionType.contract, server: transactionType.server)
                    case .erc20Token:
                        return transactionType.tokenObject
                    case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .prebuilt:
                        return nil
                    }
                }
            }.removeDuplicates()
            .flatMapLatest { [tokensPipeline, tokensService] (token: Token?) -> AnyPublisher<TokenViewModel?, Never> in
                guard let token = token else { return .just(nil) }

                tokensService.refreshBalance(updatePolicy: .token(token: token))

                return tokensPipeline.tokenViewModelPublisher(for: token)
            }.share(replay: 1)
            .eraseToAnyPublisher()
    }()

    private var title: String {
        "\(R.string.localizable.send()) \(transactionType.symbol)"
    }

    internal var transactionType: TransactionType {
        return transactionTypeSubject.value
    }

    let amountViewModel = SendViewSectionHeaderViewModel(text: R.string.localizable.sendAmount().uppercased(), showTopSeparatorLine: true)
    let recipientViewModel = SendViewSectionHeaderViewModel(text: R.string.localizable.sendRecipient().uppercased())

    init(transactionType: TransactionType,
         session: WalletSession,
         tokensPipeline: TokensProcessingPipeline,
         sessionsProvider: SessionsProvider,
         tokensService: TokensService) {

        self.tokensService = tokensService
        self.transactionTypeSubject = .init(transactionType)
        self.tokensPipeline = tokensPipeline
        self.session = session
        self.transactionTypeFromQrCode = TransactionTypeFromQrCode(sessionsProvider: sessionsProvider, session: session)
        self.transactionTypeFromQrCode.transactionTypeProvider = self
    }
    //NOTE: test purposes
    private (set) var scanQrCodeLatest: Result<TransactionType, CheckEIP681Error>?
    private (set) var latestQrCode: String?

    func transform(input: SendViewModelInput) -> SendViewModelOutput {
        var isInitialAmountToSend: Bool = true
        //NOTE: override initial value if `transactionType.amount` in nil
        // NOTE: we want to use initial value from transaction type, text field has `0` at launch, so value from transaction type will be overriden with `0`
        input.amountToSend
            .map { $0.asAmount }
            .filter { _ in
                if isInitialAmountToSend {
                    isInitialAmountToSend = false

                    return self.transactionType.amount == nil || self.transactionType.amount == .notSet
                }
                return true
            }.map { amount in
                self.amountToSend = amount

                return self.overrideTransactionType(with: amount)
            }.assign(to: \.value, on: transactionTypeSubject, ownership: .weak)
            .store(in: &cancelable)

        input.recipient
            .map { AlphaWallet.Address(string: $0) }
            .map { recipient in
                self.recipient = recipient

                return self.overrideTransactionType(with: recipient)
            }.assign(to: \.value, on: transactionTypeSubject, ownership: .weak)
            .store(in: &cancelable)

        let scanQrCode = input.qrCode
            .handleEvents(receiveOutput: { self.latestQrCode = $0 })
            .flatMap { [transactionTypeFromQrCode] in transactionTypeFromQrCode.buildTransactionType(qrCode: $0) }
            .handleEvents(receiveOutput: { [transactionTypeSubject] in
                self.scanQrCodeLatest = $0
                guard let value = $0.value else { return }
                //NOTE: we need to syncronize values for .recipient, .amountToSend and transaction type .recipient, .amount, because when active .transactionType prebuild we not able to validate amount and recipient
                self.recipient = value.recipient?.contract
                self.amountToSend = value.amount ?? .notSet

                transactionTypeSubject.value = value
            }).share()

        let transactionResult = buildUnconfirmedTransaction(send: input.send)
        let confirmTransaction = transactionResult
            .compactMap { $0.value }
            .eraseToAnyPublisher()

        let inputsValidationError = transactionResult
            .map { $0.error }
            .eraseToAnyPublisher()

        let recipientErrorState = isRecipientValid(inputsValidationError: inputsValidationError)
            .map { $0 ? TextField.TextFieldErrorState.none : TextField.TextFieldErrorState.error(InputError.invalidAddress.localizedDescription) }
            .eraseToAnyPublisher()

        let cryptoErrorState = isCryptoValueValid(cryptoValue: input.amountToSend, send: input.send)
            .map { $0 ? AmountTextField.ErrorState.none : AmountTextField.ErrorState.error }
            .eraseToAnyPublisher()

        let scanQrCodeError = scanQrCode
            .compactMap { SendViewModel.mapScanQrCodeError($0) }
            .eraseToAnyPublisher()

        let viewState = Publishers.CombineLatest(tokenViewModel, scanQrCode.mapToVoid().prepend(()))
            .flatMap { tokenViewModel, _ in asFuture { await self.buildViewState(tokenViewModel: tokenViewModel) } }
            .eraseToAnyPublisher()

        return .init(
            viewState: viewState,
            scanQrCodeError: scanQrCodeError,
            activateAmountInput: activateAmountInput(scanQrCode: scanQrCode.eraseToAnyPublisher(), didAppear: input.didAppear),
            token: tokenViewModel,
            cryptoErrorState: cryptoErrorState,
            amountTextFieldState: buildAmountTextFieldState(qrCode: scanQrCode.eraseToAnyPublisher(), allFunds: input.allFunds),
            recipientErrorState: recipientErrorState,
            confirmTransaction: confirmTransaction)
    }

    private func buildAmountTextFieldState(qrCode: AnyPublisher<Result<TransactionType, CheckEIP681Error>, Never>, allFunds: AnyPublisher<Void, Never>) -> AnyPublisher<AmountTextFieldState, Never> {

        func buildAmountTextFieldState(for transactionType: TransactionType) async -> AmountTextFieldState? {
            switch transactionType {
            case .nativeCryptocurrency(let token, _, let amount), .erc20Token(let token, _, let amount):
                switch amount {
                case .notSet:
                    return nil
                case .allFunds:
                    guard let amount = await tokensPipeline.tokenViewModel(for: token)?.balance.valueDecimal else { return nil }

                    return AmountTextFieldState(amount: .allFunds(amount.doubleValue))
                case .amount(let amount):
                    return AmountTextFieldState(amount: .amount(amount))
                }
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .prebuilt:
                return nil
            }
        }

        let initialAmount = asFuture { await buildAmountTextFieldState(for: self.transactionType) }.compactMap { $0 }.eraseToAnyPublisher()

        let amountFromQrCode: AnyPublisher<AmountTextFieldState, Never> = qrCode
            .flatMap { result in
                asFuture { () -> AmountTextFieldState? in
                    if let transactionType = result.value {
                        return await buildAmountTextFieldState(for: transactionType)
                    } else {
                        return nil
                    }
                }
            }.compactMap { $0 }
            .eraseToAnyPublisher()

        let allFundsAmount = allFunds.flatMap { [tokensPipeline, transactionTypeSubject] _ in
            asFuture { () -> AmountTextFieldState? in
                switch transactionTypeSubject.value {
                case .nativeCryptocurrency(let token, _, _), .erc20Token(let token, _, _):
                    guard let amount = await tokensPipeline.tokenViewModel(for: token)?.balance.valueDecimal else { return nil }

                    return AmountTextFieldState(amount: .allFunds(amount.doubleValue))
                case .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .prebuilt:
                    return nil
                }
            }
        }.compactMap { $0 }.eraseToAnyPublisher()

        return Publishers.MergeMany(initialAmount, amountFromQrCode, allFundsAmount)
            .eraseToAnyPublisher()
    }

    private func buildViewState(tokenViewModel: TokenViewModel?) async -> SendViewModel.ViewState {
        let amountStatusLabelHidden = await availableTextHidden
        let state = await SendViewModel.ViewState(title: title, selectCurrencyButtonState: buildSelectCurrencyButtonState(for: tokenViewModel, transactionType: transactionType), amountStatusLabelState: SendViewModel.AmountStatuLabelState(text: availableLabelText, isHidden: amountStatusLabelHidden), rate: tokenViewModel.flatMap { $0.balance.ticker.flatMap { AmountTextFieldViewModel.CurrencyRate(value: $0.price_usd, currency: $0.currency) } } ?? .init(value: nil, currency: .USD), recipientTextFieldState: buildRecipientTextFieldState(for: transactionType))
        return state
    }

    private func buildUnconfirmedTransaction(send: AnyPublisher<Void, Never>) -> AnyPublisher<Result<UnconfirmedTransaction, InputsValidationError>, Never> {
        return send
            .withLatestFrom(tokenViewModel)
            .map { tokenViewModel -> Result<UnconfirmedTransaction, InputsValidationError> in
                guard let recipient = self.recipient else {
                    return .failure(InputsValidationError.recipientInvalid)
                }
                guard let value = self.validatedAmountToSend(self.amountToSend, tokenViewModel: tokenViewModel, checkIfGreaterThanZero: self.checkIfGreaterThanZero) else {
                    return .failure(InputsValidationError.cryptoValueInvalid)
                }

                do {
                    switch self.transactionType {
                    case .nativeCryptocurrency, .prebuilt:
                        return .success(try self.transactionType.buildSendNativeCryptocurrency(recipient: recipient, amount: BigUInt(value)))
                    case .erc20Token:
                        return .success(try self.transactionType.buildSendErc20Token(recipient: recipient, amount: BigUInt(value)))
                    case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
                        throw TransactionConfiguratorError.impossibleToBuildConfiguration
                    }
                } catch {
                    return .failure(.other(error))
                }
            }.share()
            .eraseToAnyPublisher()
    }

    private func activateAmountInput(scanQrCode: AnyPublisher<Result<TransactionType, CheckEIP681Error>, Never>, didAppear: AnyPublisher<Void, Never>) -> AnyPublisher<Void, Never> {
        let whenScannedQrCode = scanQrCode
            .filter { $0.isSuccess }
            .mapToVoid()
            .eraseToAnyPublisher()

        return Publishers.Merge(whenScannedQrCode, didAppear)
            .eraseToAnyPublisher()
    }

    private func buildRecipientTextFieldState(for transactionType: TransactionType) -> RecipientTextFieldState {
        switch transactionType {
        case .nativeCryptocurrency(_, let recipient, _):
            return RecipientTextFieldState(recipient: recipient.flatMap { $0.stringValue })
        case .erc20Token(_, let recipient, _):
            return RecipientTextFieldState(recipient: recipient.flatMap { $0.stringValue })
        case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token, .prebuilt:
            return RecipientTextFieldState(recipient: nil)
        }
    }

    private func buildSelectCurrencyButtonState(for tokenViewModel: TokenViewModel?, transactionType: TransactionType) -> SendViewModel.SelectCurrencyButtonState {
        let selectCurrencyButtonHidden: Bool = {
            switch transactionType {
            case .nativeCryptocurrency, .erc20Token, .prebuilt:
                guard let ticker = tokenViewModel?.balance.ticker, ticker.price_usd > 0 else { return true }
                return false
            case .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
                return true
            }
        }()

        return .init(expandIconHidden: selectCurrencyButtonHidden)
    }

    private var availableLabelText: String? {
        get async {
            switch transactionType {
            case .nativeCryptocurrency:
                let etherToken: Token = MultipleChainsTokensDataStore.functional.etherToken(forServer: transactionType.server)
                return await tokensPipeline.tokenViewModel(for: etherToken)
                    .flatMap { return R.string.localizable.sendAvailable($0.balance.amountShort) }
            case .erc20Token(let token, _, _):
                return await tokensPipeline.tokenViewModel(for: token)
                    .flatMap { R.string.localizable.sendAvailable("\($0.balance.amountShort) \(transactionType.symbol)") }
            case .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .prebuilt:
                return nil
            }
        }
    }

    private var availableTextHidden: Bool {
        get async {
            switch transactionType {
            case .nativeCryptocurrency:
                return false
            case .erc20Token(let token, _, _):
                return await tokensPipeline.tokenViewModel(for: token)?.balance == nil
            case .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .prebuilt:
                return true
            }
        }
    }

    private var checkIfGreaterThanZero: Bool {
        switch transactionType {
        case .nativeCryptocurrency, .prebuilt:
            return false
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
            return true
        }
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
    private func isCryptoValueValid(cryptoValue: AnyPublisher<AmountTextFieldViewModel.FungibleAmount, Never>, send: AnyPublisher<Void, Never>) -> AnyPublisher<Bool, Never> {
        let whenCryptoValueHasChanged = Publishers.CombineLatest(cryptoValue, tokenViewModel)
            .map { self.validatedAmountToSend($0.asAmount, tokenViewModel: $1, checkIfGreaterThanZero: false) != nil }

        let whenSendSelected = send.withLatestFrom(tokenViewModel)
            .map { self.validatedAmountToSend(self.transactionType.amount ?? .notSet, tokenViewModel: $0, checkIfGreaterThanZero: self.checkIfGreaterThanZero) != nil }

        return Publishers.Merge(whenCryptoValueHasChanged, whenSendSelected)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    private func validatedAmountToSend(_ amount: FungibleAmount, tokenViewModel: TokenViewModel?, checkIfGreaterThanZero: Bool = true) -> BigUInt? {
        switch amount {
        case .notSet:
            return nil
        case .amount(let value):
            guard checkIfGreaterThanZero ? value > 0 : true else { return nil }

            switch transactionType {
            case .nativeCryptocurrency, .erc20Token:
                if let balance = tokenViewModel?.valueDecimal, balance.doubleValue < value {
                    return nil
                }
            case .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .prebuilt:
                break
            }

            return Decimal(value).toBigUInt(decimals: transactionType.tokenObject.decimals)
        case .allFunds:
            return tokenViewModel?.balance.value
        }
    }

    private static func mapScanQrCodeError(_ result: Result<TransactionType, CheckEIP681Error>) -> String? {
        switch result.error {
        case .tokenTypeNotSupported: return "Token Not Supported"
        case .configurationInvalid, .serverNotEnabled, .contractInvalid, .parameterInvalid, .missingRpcServer, .notEIP681, .embeded, .none: return nil
        }
    }
}

protocol TransactionTypeSupportable: AnyObject {
    var transactionType: TransactionType { get }

    func overrideTransactionType(with transactionType: TransactionType) -> TransactionType
    func overrideTransactionType(with recipient: AlphaWallet.Address?) -> TransactionType
    func overrideTransactionType(with recipient: FungibleAmount) -> TransactionType
}

extension TransactionTypeSupportable {

    func overrideTransactionType(with amount: FungibleAmount) -> TransactionType {
        var newTransactionType = self.transactionType
        newTransactionType.override(amount: amount)

        return newTransactionType
    }

    func overrideTransactionType(with recipient: AlphaWallet.Address?) -> TransactionType {
        var newTransactionType = self.transactionType
        newTransactionType.override(recipient: recipient.flatMap { .address($0) })

        return newTransactionType
    }

    func overrideTransactionType(with transactionType: TransactionType) -> TransactionType {
        var newTransactionType = transactionType
        if let recipient = newTransactionType.recipient ?? self.transactionType.recipient {
            newTransactionType.override(recipient: recipient)
        }

        switch newTransactionType.amount {
        case .notSet, .none:
            if let amount = self.transactionType.amount {
                newTransactionType.override(amount: amount)
            }
        case .amount, .allFunds:
            break
        }
        return newTransactionType
    }
}

final class TransactionTypeFromQrCode {
    private lazy var eip681UrlResolver = Eip681UrlResolver(
        sessionsProvider: sessionsProvider,
        missingRPCServerStrategy: .fallbackToPreffered(session.server))
    private let session: WalletSession
    private let sessionsProvider: SessionsProvider

    weak var transactionTypeProvider: TransactionTypeSupportable?

    init(sessionsProvider: SessionsProvider, session: WalletSession) {
        self.sessionsProvider = sessionsProvider
        self.session = session
    }

    /// Builds a new transaction type, with overriding recipient and amount if nil
    func buildTransactionType(qrCode: String) -> AnyPublisher<Result<TransactionType, CheckEIP681Error>, Never> {
        guard let transactionTypeProvider = transactionTypeProvider else {
            return Fail(error: CheckEIP681Error.notEIP681)
                .mapToResult()
                .eraseToAnyPublisher()
        }

        guard let url = URL(string: qrCode) else {
            return Fail(error: CheckEIP681Error.notEIP681)
                .mapToResult()
                .eraseToAnyPublisher()
        }

        return eip681UrlResolver
            .resolve(url: url)
            .flatMap { [session] result -> AnyPublisher<TransactionType, CheckEIP681Error> in
                switch result {
                case .transaction(let transactionType, let token):

                    guard token.server == session.server else {
                        return .fail(CheckEIP681Error.embeded(error: CheckAndFillEIP681DetailsError.serverNotMatches))
                    }

                    return .just(transactionTypeProvider.overrideTransactionType(with: transactionType))
                case .address(let recipient):
                    return .just(transactionTypeProvider.overrideTransactionType(with: recipient))
                }
            }.mapToResult()
            .eraseToAnyPublisher()
    }
}

extension TransactionTypeFromQrCode {
    fileprivate enum CheckAndFillEIP681DetailsError: LocalizedError {
        case serverNotMatches
        case tokenNotFound

        var errorDescription: String? {
            switch self {
            case .serverNotMatches:
                return "Server Not Matches"
            case .tokenNotFound:
                return "Token Not Found"
            }
        }
    }
}

extension SendViewModel {
    struct ViewState {
        let title: String
        let selectCurrencyButtonState: SendViewModel.SelectCurrencyButtonState
        let amountStatusLabelState: AmountStatuLabelState
        let rate: AmountTextFieldViewModel.CurrencyRate
        let recipientTextFieldState: RecipientTextFieldState
    }

    struct SelectCurrencyButtonState {
        let expandIconHidden: Bool
    }

    struct AmountStatuLabelState {
        let text: String?
        let isHidden: Bool
    }

    struct AmountTextFieldState {
        let amount: AmountTextFieldViewModel.FungibleAmount
    }

    struct RecipientTextFieldState {
        let recipient: String?
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
