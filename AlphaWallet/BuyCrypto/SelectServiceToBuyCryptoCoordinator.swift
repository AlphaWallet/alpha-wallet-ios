//
//  SelectServiceToBuyCryptoCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.08.2022.
//

import UIKit
import AlphaWalletFoundation

protocol SelectServiceToBuyCryptoCoordinatorDelegate: AnyObject {
    func openUrlInBrowser(url: URL, animated: Bool)
    func selectBuyService(_ result: Result<Void, BuyCryptoError>, in coordinator: SelectServiceToBuyCryptoCoordinator)
    func didClose(in coordinator: SelectServiceToBuyCryptoCoordinator)
}

class SelectServiceToBuyCryptoCoordinator: Coordinator {
    private let token: TokenActionsIdentifiable
    private let viewController: UIViewController
    private let source: Analytics.BuyCryptoSource
    private let analytics: AnalyticsLogger
    private let buyTokenProvider: BuyTokenProvider

    var coordinators: [Coordinator] = []
    weak var delegate: SelectServiceToBuyCryptoCoordinatorDelegate?

    init(buyTokenProvider: BuyTokenProvider,
         token: TokenActionsIdentifiable,
         viewController: UIViewController,
         source: Analytics.BuyCryptoSource,
         analytics: AnalyticsLogger) {

        self.buyTokenProvider = buyTokenProvider
        self.token = token
        self.viewController = viewController
        self.source = source
        self.analytics = analytics
    }

    func start(wallet: Wallet) {
        selectBuyService(wallet: wallet, completion: { result in
            switch result {
            case .service(let service):
                self.runThirdParty(wallet: wallet, service: service)
                self.delegate?.selectBuyService(.success(()), in: self)
            case .failure(let error):
                self.delegate?.selectBuyService(.failure(error), in: self)
            case .canceled:
                self.delegate?.didClose(in: self)
            }
        })
    }

    private func runThirdParty(wallet: Wallet, service: BuyTokenURLProviderType & SupportedTokenActionsProvider) {
        let coordinator = BuyCryptoUsingThirdPartyCoordinator(
            service: service,
            token: token,
            source: source,
            analytics: analytics)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start(wallet: wallet)
    }

    private enum BuyCryptoUsingService {
        case service(BuyTokenURLProviderType & SupportedTokenActionsProvider)
        case failure(error: BuyCryptoError)
        case canceled
    }

    private func selectBuyService(wallet: Wallet, completion: @escaping (BuyCryptoUsingService) -> Void) {
        typealias ActionToService = (service: BuyTokenURLProviderType & SupportedTokenActionsProvider, action: UIAlertAction)

        let actions = buyTokenProvider.services.compactMap { service -> ActionToService? in
            guard service.isSupport(token: token) && service.url(token: token, wallet: wallet) != nil else { return nil }

            return (service, UIAlertAction(title: service.action, style: .default) { _ in completion(.service(service)) })
        }

        if actions.isEmpty {
            completion(.failure(error: BuyCryptoError.buyNotSupported))
        } else if actions.count == 1 {
            completion(.service(actions[0].service))
        } else {
            let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: preferredStyle)
            for each in actions {
                alertController.addAction(each.action)
            }

            alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in completion(.canceled) })
            viewController.present(alertController, animated: true)
        }
    }
}

extension SelectServiceToBuyCryptoCoordinator: BuyCryptoUsingThirdPartyCoordinatorDelegate {
    func openUrlInBrowser(url: URL, animated: Bool) {
        delegate?.openUrlInBrowser(url: url, animated: animated)
    }
}
