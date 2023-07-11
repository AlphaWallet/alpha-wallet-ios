//
// Created by James Sangalli on 7/3/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import AlphaWalletFoundation

protocol ClaimOrderCoordinatorDelegate: CanOpenURL, BuyCryptoDelegate {
    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didFailTransaction error: Error)
    func didClose(in coordinator: ClaimPaidOrderCoordinator)
    func coordinator(_ coordinator: ClaimPaidOrderCoordinator, didCompleteTransaction result: ConfirmResult)
}

class ClaimPaidOrderCoordinator: Coordinator {
    private let navigationController: UINavigationController
    private let tokensService: TokensProcessingPipeline
    private let keystore: Keystore
    private let session: WalletSession
    private let token: Token
    private let signedOrder: SignedOrder
    private let analytics: AnalyticsLogger
    private let domainResolutionService: DomainNameResolutionServiceType
    private let assetDefinitionStore: AssetDefinitionStore
    private var numberOfTokens: UInt {
        if let tokenIds = signedOrder.order.tokenIds, !tokenIds.isEmpty {
            return UInt(tokenIds.count)
        } else if signedOrder.order.nativeCurrencyDrop {
            return 1
        } else {
            return UInt(signedOrder.order.indices.count)
        }
    }
    private let networkService: NetworkService

    var coordinators: [Coordinator] = []
    weak var delegate: ClaimOrderCoordinatorDelegate?

    init(navigationController: UINavigationController,
         keystore: Keystore,
         session: WalletSession,
         token: Token,
         signedOrder: SignedOrder,
         analytics: AnalyticsLogger,
         domainResolutionService: DomainNameResolutionServiceType,
         assetDefinitionStore: AssetDefinitionStore,
         tokensService: TokensProcessingPipeline,
         networkService: NetworkService) {
        self.networkService = networkService
        self.navigationController = navigationController
        self.tokensService = tokensService
        self.keystore = keystore
        self.session = session
        self.token = token
        self.signedOrder = signedOrder
        self.analytics = analytics
        self.domainResolutionService = domainResolutionService
        self.assetDefinitionStore = assetDefinitionStore
    }

    func start() {
        do {
            let transaction = try TransactionType.prebuilt(token.server).buildClaimPaidErc875MagicLink(
                recipient: session.account.address,
                signedOrder: signedOrder)

            let coordinator = TransactionConfirmationCoordinator(
                presentingViewController: navigationController,
                session: session,
                transaction: transaction,
                configuration: .claimPaidErc875MagicLink(
                    confirmType: .signThenSend,
                    price: signedOrder.order.price,
                    numberOfTokens: numberOfTokens),
                analytics: analytics,
                domainResolutionService: domainResolutionService,
                keystore: keystore,
                tokensService: tokensService,
                networkService: networkService)

            coordinator.delegate = self
            addCoordinator(coordinator)
            coordinator.start(fromSource: .claimPaidMagicLink)
        } catch {
            UIApplication.shared
                .presentedViewController(or: navigationController)
                .displayError(message: error.localizedDescription)
        }
    }
}

extension ClaimPaidOrderCoordinator: TransactionConfirmationCoordinatorDelegate {
    func coordinator(_ coordinator: TransactionConfirmationCoordinator, didFailTransaction error: Error) {
        UIApplication.shared
            .presentedViewController(or: navigationController)
            .displayError(message: error.localizedDescription)

        delegate?.coordinator(self, didFailTransaction: error)
    }

    func didClose(in coordinator: TransactionConfirmationCoordinator) {
        delegate?.didClose(in: self)
        removeCoordinator(coordinator)
    }

    func didSendTransaction(_ transaction: SentTransaction, inCoordinator coordinator: TransactionConfirmationCoordinator) {
        // no-op
    }

    func didFinish(_ result: ConfirmResult, in coordinator: TransactionConfirmationCoordinator) {
        coordinator.close { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.coordinator(strongSelf, didCompleteTransaction: result)
        }
        removeCoordinator(coordinator)
    }

    func buyCrypto(wallet: Wallet, server: RPCServer, viewController: UIViewController, source: Analytics.BuyCryptoSource) {
        delegate?.buyCrypto(wallet: wallet, server: server, viewController: viewController, source: .transactionActionSheetInsufficientFunds)
    }
}

extension ClaimPaidOrderCoordinator: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
