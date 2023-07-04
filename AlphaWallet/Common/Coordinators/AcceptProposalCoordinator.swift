//
//  AcceptProposalCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import UIKit
import AlphaWalletFoundation

protocol AcceptProposalCoordinatorDelegate: AnyObject {
    func coordinator(_ coordinator: AcceptProposalCoordinator, didComplete result: ProposalResult)
}

class AcceptProposalCoordinator: Coordinator {
    var coordinators: [Coordinator] = []

    private let analytics: AnalyticsLogger
    private let proposalType: ProposalType
    private let navigationController: UINavigationController
    private lazy var viewModel = AcceptProposalViewModel(proposalType: proposalType, analytics: analytics)
    private lazy var rootViewController: AcceptProposalViewController = {
        let viewController = AcceptProposalViewController(viewModel: viewModel)
        viewController.delegate = self

        return viewController
    }()
    private lazy var hostViewController: FloatingPanelController = {
        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = SelfSizingPanelLayout(referenceGuide: .superview)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self
        panel.set(contentViewController: rootViewController)

        return panel
    }()
    private let restartHandler: RestartQueueHandler

    weak var delegate: AcceptProposalCoordinatorDelegate?

    init(analytics: AnalyticsLogger, proposalType: ProposalType, navigationController: UINavigationController, restartHandler: RestartQueueHandler) {
        self.restartHandler = restartHandler
        self.analytics = analytics
        self.proposalType = proposalType
        self.navigationController = navigationController
    }

    func start() {
        viewModel.logStart()

        let presenter = UIApplication.shared.presentedViewController(or: navigationController)
        presenter.present(hostViewController, animated: true)

        rootViewController.reloadView()
    }

    func close(completion: @escaping () -> Void) {
        hostViewController.dismiss(animated: true, completion: completion)
    }
}

extension AcceptProposalCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.coordinator(self, didComplete: .cancel)
    }
}

extension AcceptProposalCoordinator: ServersCoordinatorDelegate {

    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)

        viewModel.logServerSelected()

        switch viewModel.proposalType {
        case .walletConnect(let viewModel):
            viewModel.set(serversToConnect: selection.asServersArray)
        case .deepLink:
            break
        }
        rootViewController.reloadView()
    }

    func didClose(in coordinator: ServersCoordinator) {
        coordinator.navigationController.dismiss(animated: true)
        removeCoordinator(coordinator)

        viewModel.logCancelServerSelection()
    }
}

extension AcceptProposalCoordinator: AcceptProposalViewControllerDelegate {

    func didInvalidateLayout(in controller: AcceptProposalViewController) {
        hostViewController.invalidateLayout()
    }

    func changeConnectionServerSelected(in controller: AcceptProposalViewController) {
        viewModel.logSwitchServer()

        switch viewModel.proposalType {
        case .walletConnect(let viewModel):
            let navigationController = NavigationController()
            navigationController.makePresentationFullScreenForiOS13Migration()

            let coordinator = ServersCoordinator(
                viewModel: viewModel.serversViewModel,
                navigationController: navigationController)

            coordinator.serversViewController.navigationItem.rightBarButtonItem = .closeBarButton(self, selector: #selector(changeServersDidDismiss))
            coordinator.start(animated: false)
            coordinator.delegate = self

            addCoordinator(coordinator)

            hostViewController.present(navigationController, animated: true)
        case .deepLink:
            break
        }
    }

    @objc private func changeServersDidDismiss() {
        guard let coordinator = coordinatorOfType(type: ServersCoordinator.self) else { return }
        coordinator.navigationController.dismiss(animated: true)
        coordinator.serversViewController.didPopViewController(animated: true)
    }

    func controller(_ controller: AcceptProposalViewController, continueButtonTapped sender: UIButton) {
        processProposal()
    }

    func didClose(in controller: AcceptProposalViewController) {
        viewModel.logApproveCancelation()
        close(completion: {
            self.delegate?.coordinator(self, didComplete: .cancel)
        })
    }

    private func processProposal() {
        switch viewModel.proposalType {
        case .walletConnect(let viewModel):
            do {
                try viewModel.validateEnabledServers(serversToConnect: viewModel.serversToConnect)
                self.viewModel.logConnectToServers()

                UINotificationFeedbackGenerator.show(feedbackType: .success)

                close(completion: {
                    //NOTE: all the time we should have at least 1 server to connect
                    guard let server = viewModel.serversToConnect.first else { return }
                    self.delegate?.coordinator(self, didComplete: .walletConnect(server))
                })
            } catch let error as MissingRpcServerError {
                self.viewModel.logConnectToServersDisabled(servers: error.servers)

                showServerUnavaible(disabledServers: error.servers)
            } catch { /*no-op*/ }

        case .deepLink:
            UINotificationFeedbackGenerator.show(feedbackType: .success)

            close(completion: {
                self.delegate?.coordinator(self, didComplete: .deepLink)
            })
        }
    }

    private func showServerUnavaible(disabledServers: [RPCServer]) {
        let coordinator = ServerUnavailableCoordinator(
            navigationController: navigationController,
            disabledServers: disabledServers,
            restartHandler: restartHandler)

        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }
}

extension AcceptProposalCoordinator: ServerUnavailableCoordinatorDelegate {

    func didDismiss(in coordinator: ServerUnavailableCoordinator, result: Swift.Result<Void, Error>) {
        removeCoordinator(coordinator)

        guard case .success = result else { return }
        processProposal()
    }
}
