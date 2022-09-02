//
//  SelectServiceToSwapCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 24.08.2022.
//

import UIKit
import AlphaWalletFoundation

protocol SelectServiceToSwapCoordinatorDelegate: AnyObject {
    func selectSwapService(_ result: Result<SwapTokenUsing, SwapTokenError>, in coordinator: SelectServiceToSwapCoordinator)
    func didClose(in coordinator: SelectServiceToSwapCoordinator)
}

class SelectServiceToSwapCoordinator: Coordinator {
    private let token: Token
    private let viewController: UIViewController
    private let swapTokenProvider: SwapTokenProvider

    var coordinators: [Coordinator] = []
    weak var delegate: SelectServiceToSwapCoordinatorDelegate?

    init(swapTokenProvider: SwapTokenProvider, token: Token, viewController: UIViewController) {
        self.swapTokenProvider = swapTokenProvider
        self.token = token
        self.viewController = viewController
    }

    func start(wallet: Wallet) {
        selectSwapService(wallet: wallet, completion: { [token] result in
            switch result {
            case .service(let service):
                if let service = service as? SwapTokenViaUrlProvider {
                    if let url = service.url(token: token) {
                        let server = service.rpcServer(forToken: token)
                        self.delegate?.selectSwapService(.success(.url(url: url, server: server)), in: self)
                    } else {
                        self.delegate?.selectSwapService(.failure(SwapTokenError.swapNotSuppoted), in: self)
                    }
                } else if let _ = service as? SwapTokenNativeProvider {
                    let swapPair = SwapPair(from: token, to: nil)
                    self.delegate?.selectSwapService(.success(.native(swapPair: swapPair)), in: self)
                } else {
                    self.delegate?.selectSwapService(.failure(SwapTokenError.swapNotSuppoted), in: self)
                }
            case .failure(let error):
                self.delegate?.selectSwapService(.failure(error), in: self)
            case .canceled:
                self.delegate?.didClose(in: self)
            }
        })
    }

    private func selectSwapService(wallet: Wallet, completion: @escaping (SwapTokenUsingService) -> Void) {
        typealias ActionToService = (service: SwapTokenActionProvider, action: UIAlertAction)

        let actions = swapTokenProvider.services.compactMap { service -> ActionToService? in
            guard service.isSupport(token: token) else { return nil }

            return (service, UIAlertAction(title: service.action, style: .default) { _ in completion(.service(service)) })
        }

        if actions.isEmpty {
            completion(.failure(.swapNotSuppoted))
            return
        } else if actions.count == 1 {
            completion(.service(actions[0].service))
            return
        }

        let alertController = UIAlertController(title: nil, message: .none, preferredStyle: .actionSheet)
        for each in actions {
            alertController.addAction(each.action)
        }

        alertController.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in completion(.canceled) })
        viewController.present(alertController, animated: true)
    }
}

extension SelectServiceToSwapCoordinator {

    enum SwapTokenAction {
        case usingUrl(url: URL, server: RPCServer?)
        case native(swapPair: SwapPair)
    }

    private typealias SwapTokenActionProvider = SupportedTokenActionsProvider & TokenActionProvider

    private enum SwapTokenUsingService {
        case service(SwapTokenActionProvider)
        case failure(SwapTokenError)
        case canceled
    }
}
