// Copyright SIX DAY LLC. All rights reserved.

import BigInt
import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct TransactionDetailsViewModelInput {
    let openUrl: AnyPublisher<Void, Never>
    let copyToClipboard: AnyPublisher<TransactionDetailsViewModel.CopyableField, Never>
}

struct TransactionDetailsViewModelOutput {
    let viewState: AnyPublisher<TransactionDetailsViewModel.ViewState, Never>
    let copiedToClipboard: AnyPublisher<String, Never>
    let openUrl: AnyPublisher<URL, Never>
}

class TransactionDetailsViewModel {
    private var transactionRow: TransactionRow
    private let blockNumberProvider: BlockNumberProvider
    private let fullFormatter = EtherNumberFormatter.full
    private let analytics: AnalyticsLogger
    private let transactionsService: TransactionsService
    private let tokensService: TokensProcessingPipeline
    private let wallet: Wallet
    private let tokenImageFetcher: TokenImageFetcher
    private var moreButtonTitle: String {
        if let name = ConfigExplorer(server: server).transactionUrl(for: transactionRow.id)?.name {
            return R.string.localizable.viewIn(name)
        } else {
            return R.string.localizable.moreDetails()
        }
    }
    private var detailsURL: URL? { ConfigExplorer(server: server).transactionUrl(for: transactionRow.id)?.url }

    var shareItem: URL? { detailsURL }
    var server: RPCServer { transactionRow.server }
    var shareAvailable: Bool { detailsAvailable }

    init(transactionsService: TransactionsService,
         transactionRow: TransactionRow,
         blockNumberProvider: BlockNumberProvider,
         wallet: Wallet,
         tokensService: TokensProcessingPipeline,
         analytics: AnalyticsLogger,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.wallet = wallet
        self.tokensService = tokensService
        self.transactionsService = transactionsService
        self.transactionRow = transactionRow
        self.blockNumberProvider = blockNumberProvider
        self.analytics = analytics
    }

    func transform(input: TransactionDetailsViewModelInput) -> TransactionDetailsViewModelOutput {
        let transactionRow: AnyPublisher<TransactionRow, Never> = { [transactionsService, transactionRow] in
            let whenTransactionHasChanged = transactionsService.transactionPublisher(for: transactionRow.id, server: transactionRow.server)
                .dropFirst(1)
                .compactMap { $0 }
                .receive(on: RunLoop.main)
                .map { transaction -> TransactionRow in
                    if transaction.localizedOperations.count > 1 {
                        return .group(transaction)
                    } else {
                        return .standalone(transaction)
                    }
                }
            
            return Publishers.Merge(whenTransactionHasChanged, Just(self.transactionRow))
                .removeDuplicates()
                .eraseToAnyPublisher()
        }()

        let gasViewModel = tokensService.tokenViewModelPublisher(for: Constants.nativeCryptoAddressInDatabase, server: server)
            .map { token -> GasViewModel in
                return self.buildGasViewModel(transactionRow: self.transactionRow, coinTicker: token?.balance.ticker)
            }

        let viewState = Publishers.CombineLatest3(transactionRow, gasViewModel, blockNumberProvider.latestBlockPublisher)
            .map { [blockNumberProvider, wallet] transactionRow, gasViewModel, _ -> TransactionDetailsViewModel.ViewState in
                let transactionViewModel = TransactionViewModel(transactionRow: transactionRow, blockNumberProvider: blockNumberProvider, wallet: wallet)
                return self.buildViewState(transactionRow: transactionRow, transactionViewModel: transactionViewModel, gasViewModel: gasViewModel)
            }.eraseToAnyPublisher()

        let copiedToClipboard = copyToClipboard(trigger: input.copyToClipboard)

        let openUrl = input.openUrl
            .compactMap { _ in self.detailsURL }
            .handleEvents(receiveOutput: { _ in self.logUse() })
            .eraseToAnyPublisher()

        return .init(viewState: viewState, copiedToClipboard: copiedToClipboard, openUrl: openUrl)
    }

    private func buildViewState(transactionRow: TransactionRow, transactionViewModel: TransactionViewModel, gasViewModel: GasViewModel) -> TransactionDetailsViewModel.ViewState {
        let header = TransactionHeaderViewModel(transactionViewModel: transactionViewModel, tokensService: tokensService, tokenImageFetcher: tokenImageFetcher)

        return .init(header: header, from: transactionRow.from, to: to, gasFee: gasViewModel.feeText, confirmation: confirmation, transactionId: transactionRow.id, createdAt: createdAt, blockNumber: String(transactionRow.blockNumber), nonce: String(transactionRow.nonce), barIsHidden: !detailsAvailable, server: server, moreButtonTitle: moreButtonTitle)
    }

    private func copyToClipboard(trigger: AnyPublisher<TransactionDetailsViewModel.CopyableField, Never>) -> AnyPublisher<String, Never> {
        trigger.map { field -> String in
            switch field {
            case .to: UIPasteboard.general.string = self.to
            case .from: UIPasteboard.general.string = self.transactionRow.from
            case .transactionId: UIPasteboard.general.string = self.transactionRow.id
            }
            return field.hint
        }.eraseToAnyPublisher()
    }

    private var createdAt: String {
        return Date.formatter(with: "dd MMM yyyy h:mm:ss a").string(from: transactionRow.date)
    }

    private var detailsAvailable: Bool {
        return detailsURL != nil
    }

    private var to: String {
        switch transactionRow {
        case .standalone(let transaction):
            return transaction.operation?.to ?? transaction.to
        case .group(let transaction):
            return transaction.to
        case .item(_, operation: let operation):
            return operation.to
        }
    }

    private func buildGasViewModel(transactionRow: TransactionRow, coinTicker: CoinTicker?) -> GasViewModel {
        let gasUsed = BigUInt(transactionRow.gasUsed) ?? BigUInt()
        let gasPrice = BigUInt(transactionRow.gasPrice) ?? BigUInt()
        let gasLimit = BigUInt(transactionRow.gas) ?? BigUInt()
        
        let gasFee: BigUInt
        switch transactionRow.state {
        case .completed, .error:
            gasFee = gasPrice * gasUsed
        case .pending, .unknown, .failed:
            gasFee = gasPrice * gasLimit
        }
        let rate = coinTicker.flatMap { CurrencyRate(currency: $0.currency, value: $0.price_usd) }
        
        return GasViewModel(fee: gasFee, symbol: server.symbol, rate: rate, formatter: fullFormatter)
    }

    private var confirmation: String {
        guard let confirmation = blockNumberProvider.confirmations(fromBlock: transactionRow.blockNumber) else {
            return "--"
        }
        return String(confirmation)
    }

    private func logUse() {
        analytics.log(navigation: Analytics.Navigation.explorer, properties: [Analytics.Properties.type.rawValue: Analytics.ExplorerType.transaction.rawValue])
    }
}

extension TransactionDetailsViewModel {
    enum CopyableField {
        case from
        case to
        case transactionId

        var hint: String {
            switch self {
            case .to: return R.string.localizable.copiedToClipboardTitle(R.string.localizable.address())
            case .from: return R.string.localizable.copiedToClipboardTitle(R.string.localizable.address())
            case .transactionId: return R.string.localizable.copiedToClipboardTitle(R.string.localizable.transactionId())
            }
        }
    }

    struct ViewState {
        let title: String = R.string.localizable.transactionNavigationTitle()
        let header: TransactionHeaderViewModel
        let from: String
        let to: String
        let gasFee: String
        let confirmation: String
        let transactionId: String
        let createdAt: String
        let blockNumber: String
        let nonce: String
        let barIsHidden: Bool
        let server: RPCServer
        let moreButtonTitle: String
    }
}
