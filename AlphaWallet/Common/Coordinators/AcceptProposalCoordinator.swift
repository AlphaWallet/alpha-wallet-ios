//
//  AcceptProposalCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2021.
//

import UIKit
import PromiseKit
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
    private weak var serversViewController: UIViewController?
    private lazy var hostViewController: FloatingPanelController = {
        let panel = FloatingPanelController(isPanEnabled: false)
        panel.layout = SelfSizingPanelLayout(referenceGuide: .superview)
        panel.shouldDismissOnBackdrop = true
        panel.delegate = self
        panel.set(contentViewController: rootViewController)

        return panel
    }()

    weak var delegate: AcceptProposalCoordinatorDelegate?

    init(analytics: AnalyticsLogger, proposalType: ProposalType, navigationController: UINavigationController) {
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
        navigationController.dismiss(animated: true, completion: completion)
    }
}

extension AcceptProposalCoordinator: FloatingPanelControllerDelegate {
    func floatingPanelDidRemove(_ fpc: FloatingPanelController) {
        delegate?.coordinator(self, didComplete: .cancel)
    }
}

extension AcceptProposalCoordinator: ServersCoordinatorDelegate {

    func didSelectServer(selection: ServerSelection, in coordinator: ServersCoordinator) {
        removeCoordinator(coordinator)
        serversViewController?.navigationController?.dismiss(animated: true)

        viewModel.logServerSelected()

        switch viewModel.proposalType {
        case .walletConnect(let viewModel):
            viewModel.set(serversToConnect: selection.asServersArray)
        case .deepLink:
            break
        }
        rootViewController.reloadView()
    }

    func didSelectDismiss(in coordinator: ServersCoordinator) {
        removeCoordinator(coordinator)
        serversViewController?.navigationController?.dismiss(animated: true)
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
            let coordinator = ServersCoordinator(viewModel: viewModel.serversViewModel, navigationController: navigationController)
            addCoordinator(coordinator)
            coordinator.delegate = self

            let navigationController = NavigationController(rootViewController: coordinator.serversViewController)
            navigationController.makePresentationFullScreenForiOS13Migration()
            controller.navigationItem.leftBarButtonItem = .closeBarButton(self, selector: #selector(changeServersDidDismiss))

            self.serversViewController = coordinator.serversViewController

            hostViewController.present(navigationController, animated: true)
        case .deepLink:
            break
        }
    }

    @objc func changeServersDidDismiss() {
        serversViewController?.navigationController?.dismiss(animated: true)
    }

    func controller(_ controller: AcceptProposalViewController, continueButtonTapped sender: UIButton) {
        switch viewModel.proposalType {
        case .walletConnect(let viewModel):
            do {
                try viewModel.validateEnabledServers(serversToConnect: viewModel.serversToConnect)
                self.viewModel.logConnectToServers()

                UINotificationFeedbackGenerator.show(feedbackType: .success)

                self.close(completion: {
                    //NOTE: all the time we should have at least 1 server to connect
                    guard let server = viewModel.serversToConnect.first else { return }
                    self.delegate?.coordinator(self, didComplete: .walletConnect(server))
                })
            } catch {
                self.viewModel.logConnectToServersDisabled()

                showServerUnavaible(for: viewModel.serversToConnect)
            }
        case .deepLink:
            UINotificationFeedbackGenerator.show(feedbackType: .success)

            self.close(completion: {
                self.delegate?.coordinator(self, didComplete: .deepLink)
            })
        }
    }

    func didClose(in controller: AcceptProposalViewController) {
        viewModel.logApproveCancelation()
        close(completion: {
            self.delegate?.coordinator(self, didComplete: .cancel)
        })
    }

    private func showServerUnavaible(for servers: [RPCServer]) {
        let coordinator = ServerUnavailableCoordinator(navigationController: navigationController, servers: servers)
        coordinator.delegate = self
        addCoordinator(coordinator)
        coordinator.start()
    }
}

extension AcceptProposalCoordinator: ServerUnavailableCoordinatorDelegate {
    func didDismiss(in coordinator: ServerUnavailableCoordinator) {
        removeCoordinator(coordinator)
    }
}
