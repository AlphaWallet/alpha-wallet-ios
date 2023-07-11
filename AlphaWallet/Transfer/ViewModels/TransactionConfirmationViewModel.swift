// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletFoundation

struct TransactionConfirmationViewModelInput {

}

struct TransactionConfirmationViewModelOutput {
    let viewState: AnyPublisher<TransactionConfirmationViewModel.ViewState, Never>
}

protocol TransactionConfirmationViewModelType: ExpandableSection {
    var confirmButtonViewModel: ConfirmButtonViewModel { get }

    func transform(input: TransactionConfirmationViewModelInput) -> TransactionConfirmationViewModelOutput
    func shouldShowChildren(for section: Int, index: Int) -> Bool
}

struct TransactionConfirmationViewModel {

    static func buildViewModel(configurator: TransactionConfigurator,
                               configuration: TransactionType.Configuration,
                               domainResolutionService: DomainNameResolutionServiceType,
                               tokensService: TokensProcessingPipeline) -> TransactionConfirmationViewModelType {

        let recipientOrContract = configurator.transaction.recipient ?? configurator.transaction.contract
        let recipientResolver = RecipientResolver(address: recipientOrContract, server: configurator.session.server, domainResolutionService: domainResolutionService)
        switch configuration {
        case .tokenScriptTransaction(_, let contract, let functionCallMetaData):
            return TokenScriptTransactionViewModel(
                address: contract,
                configurator: configurator,
                functionCallMetaData: functionCallMetaData,
                tokensService: tokensService)
        case .dappTransaction:
            return DappOrWalletConnectTransactionViewModel(
                configurator: configurator,
                recipientResolver: recipientResolver,
                requester: nil,
                tokensService: tokensService)
        case .walletConnect(_, let requester):
            return DappOrWalletConnectTransactionViewModel(
                configurator: configurator,
                recipientResolver: recipientResolver,
                requester: requester,
                tokensService: tokensService)
        case .sendFungiblesTransaction:
            return SendFungiblesTransactionViewModel(
                configurator: configurator,
                recipientResolver: recipientResolver,
                tokensService: tokensService)
        case .sendNftTransaction:
            return SendNftTransactionViewModel(
                configurator: configurator,
                recipientResolver: recipientResolver,
                tokensService: tokensService)
        case .claimPaidErc875MagicLink(_, let price, let numberOfTokens):
            return ClaimPaidErc875MagicLinkViewModel(
                configurator: configurator,
                price: price,
                numberOfTokens: numberOfTokens,
                tokensService: tokensService)
        case .speedupTransaction:
            return SpeedupTransactionViewModel(
                configurator: configurator,
                tokensService: tokensService)
        case .cancelTransaction:
            return CancelTransactionViewModel(
                configurator: configurator,
                tokensService: tokensService)
        case .swapTransaction(let fromToken, let fromAmount, let toToken, let toAmount):
            return SwapTransactionViewModel(
                configurator: configurator,
                fromToken: fromToken,
                fromAmount: fromAmount,
                toToken: toToken,
                toAmount: toAmount,
                tokensService: tokensService)
        case .approve:
            //TODO rename `.dappOrWalletConnectTransaction` so it's more general?
            return DappOrWalletConnectTransactionViewModel(
                configurator: configurator,
                recipientResolver: recipientResolver,
                requester: nil,
                tokensService: tokensService)
        }
    }
}

extension TransactionConfirmationViewModel {

    struct ViewState {
        let title: String
        let views: [ViewType]
        let isSeparatorHidden: Bool
    }

    enum ViewType {
        case separator(height: CGFloat)
        case details(viewModel: TransactionRowDescriptionTableViewCellViewModel)
        case view(viewModel: TransactionConfirmationRowInfoViewModel, isHidden: Bool)
        case recipient(viewModel: TransactionConfirmationRecipientRowInfoViewModel, isHidden: Bool)
        case header(viewModel: TransactionConfirmationHeaderViewModel, isEditEnabled: Bool)
    }

    enum State {
        case ready
        case pending
        case done(withError: Bool)
    }

    enum ExpandOrCollapseAction {
        case expand
        case collapse
    }

    static func gasFeeString(for configurator: TransactionConfigurator, rate: CurrencyRate?) -> String {
        let fee = Decimal(bigUInt: configurator.gasFee, decimals: configurator.session.server.decimals) ?? .zero
        let estimatedProcessingTime = configurator.selectedGasSpeed.estimatedProcessingTime
        let feeString = NumberFormatter.shortCrypto.string(decimal: fee) ?? "-"
        let costs: String
        if let rate = rate {
            let amountInFiat = NumberFormatter.fiat(currency: rate.currency).string(double: fee.doubleValue * rate.value) ?? "-"

            costs =  "< ~\(feeString) \(configurator.session.server.symbol) (\(amountInFiat))"
        } else {
            costs = "< ~\(feeString) \(configurator.session.server.symbol)"
        }

        if estimatedProcessingTime.isEmpty {
            return costs
        } else {
            return "\(costs) \(estimatedProcessingTime)"
        }
    }
}
