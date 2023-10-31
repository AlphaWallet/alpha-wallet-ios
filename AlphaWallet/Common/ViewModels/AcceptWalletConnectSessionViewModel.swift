//
//  AcceptWalletConnectSessionViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.06.2022.
//

import Foundation
import AlphaWalletFoundation
import Combine

struct MissingRpcServerError: Error {
    let servers: [RPCServer]
}

final class AcceptWalletConnectSessionViewModel: ExpandableSection {
    private let serversProvider: ServersProvidable
    private let proposal: AlphaWallet.WalletConnect.Proposal
    private (set) var serversToConnect: [RPCServer]
    private var serverChoices: [RPCServer] {
        ServersCoordinator.serversOrdered.filter { serversProvider.enabledServers.contains($0) }
    }
    var openedSections: Set<Int> = .init()
    let methods: [String]
    var connectionIconUrl: URL? { proposal.iconUrl }

    var serversViewModel: ServersViewModel {
        let servers = serverChoices.filter { serversProvider.enabledServers.contains($0) } .compactMap { RPCServerOrAuto.server($0) }
        let serversToConnect: [RPCServerOrAuto] = serversToConnect.map { .server($0) }
        //NOTE: multiple server selection is disable for this case
        return ServersViewModel(servers: servers, selectedServers: serversToConnect, displayWarningFooter: false)
    }

    init(proposal: AlphaWallet.WalletConnect.Proposal,
         serversProvider: ServersProvidable) {

        self.proposal = proposal
        //TODO: refactor later with using servers from each level of received namepaces
        //We have to make chains unique as required and optional can have overlapping chains because they are requesting for different permissions for the same chain. eg. required mainnet+chainChanged and optional mainnet+eth_sendTransaction
        self.serversToConnect = functional.uniqueSortedServersFromServers(proposal.requiredNamespaces.flatMap { Array($0.chains) } + proposal.optionalNamespaces.flatMap { Array($0.chains) })
        self.methods = []//proposal.methods
        self.serversProvider = serversProvider
    }

    func set(serversToConnect: [RPCServer]) {
        self.serversToConnect = serversToConnect
    }

    var title: String {
        return R.string.localizable.walletConnectConnectionTitle()
    }

    var connectButtonTitle: String {
        return R.string.localizable.confirmPaymentConnectButtonTitle()
    }

    var rejectButtonTitle: String {
        return R.string.localizable.confirmPaymentRejectButtonTitle()
    }

    private var sections: [Section] {
        var sections: [Section] = [.name, .url]
        sections += [.networks]
        //sections += methods.isEmpty ? [] : [.methods]
        //TODO: display events
        return sections
    }

    private var editButtonEnabled: Bool {
        return proposal.serverEditing == .enabled
    }

    func validateEnabledServers(serversToConnect: [RPCServer]) throws {
        let missingServers = serversToConnect.filter { !serversProvider.enabledServers.contains($0) }
        if missingServers.isEmpty {
            //no-op
        } else {
            throw MissingRpcServerError(servers: missingServers)
        }
    }

    func isSubviewsHidden(section: Int, row: Int) -> Bool {
        let isOpened = openedSections.contains(section)
        switch sections[section] {
        case .name, .url:
            return true
        case .networks:
            switch proposal.serverEditing {
            case .notSupporting:
                return false
            case .disabled, .enabled:
                return isOpened
            }
        case .methods:
            return isOpened
        }
    }

    private var serversSectionTitle: String {
        switch proposal.serverEditing {
        case .notSupporting:
            return R.string.localizable.walletConnectConnectionNetworksTitle()
        case .disabled, .enabled:
            return R.string.localizable.walletConnectConnectionNetworkTitle()
        }
    }

    private func headerViewModel(section: Int) -> TransactionConfirmationHeaderViewModel {
        let isOpened = openedSections.contains(section)

        switch sections[section] {
        case .name:
            let name = proposal.name.trimmed.isEmpty ? "--" : proposal.name.trimmed
            return .init(title: .normal(name), headerName: sections[section].title, viewState: .init(section: section))
        case .networks:
            let servers = serversToConnect.map { $0.displayName }.joined(separator: ", ")
            let shouldHideChevron = proposal.serverEditing == .notSupporting || serversToConnect.count == 1
            let viewState = TransactionConfirmationHeaderViewModel.ViewState(
                isOpened: isOpened,
                section: section,
                shouldHideChevron: shouldHideChevron)
            let serverIcon = serversToConnect.first?.walletConnectIconImage ?? .just(nil)

            return .init(title: .normal(servers), headerName: serversSectionTitle, titleIcon: serverIcon, viewState: viewState)
        case .url:
            let dappUrl = proposal.dappUrl.absoluteString
            return .init(title: .normal(dappUrl), headerName: sections[section].title, viewState: .init(section: section))
        case .methods:
            let methods = methods.joined(separator: ", ")
            let viewState = TransactionConfirmationHeaderViewModel.ViewState(
                isOpened: isOpened,
                section: section,
                shouldHideChevron: !sections[section].isExpandable)

            return .init(title: .normal(methods), headerName: sections[section].title, viewState: viewState)
        }
    }

    var viewModels: [AcceptProposalViewModel.ViewModelType] {
        var _viewModels: [AcceptProposalViewModel.ViewModelType] = []

        for (sectionIndex, section) in sections.enumerated() {
            switch section {
            case .networks:
                _viewModels += [.header(viewModel: headerViewModel(section: sectionIndex), editButtonEnabled: editButtonEnabled)]

                for (rowIndex, server) in serversToConnect.enumerated() {
                    let isHidden = !isSubviewsHidden(section: sectionIndex, row: rowIndex)

                    _viewModels += [.serverField(viewModel: .init(server: server), isHidden: isHidden)]
                }
            case .name, .url:
                _viewModels += [.header(viewModel: headerViewModel(section: sectionIndex), editButtonEnabled: false)]
            case .methods:
                _viewModels += [.header(viewModel: headerViewModel(section: sectionIndex), editButtonEnabled: false)]
                for (rowIndex, method) in methods.enumerated() {
                    let isHidden = !isSubviewsHidden(section: sectionIndex, row: rowIndex)

                    _viewModels += [.anyField(viewModel: .init(title: method, subtitle: nil), isHidden: isHidden)]
                }
            }
        }

        return _viewModels
    }
}

extension AcceptWalletConnectSessionViewModel {
    enum functional {}
}

fileprivate extension AcceptWalletConnectSessionViewModel.functional {
    static func uniqueSortedServersFromServers(_ servers: [RPCServer]) -> [RPCServer] {
        let uniqueChains = Set(servers)
        return Array(uniqueChains).sorted(by: { $0.displayOrderPriority > $1.displayOrderPriority })
    }
}

extension AcceptWalletConnectSessionViewModel {
    enum Section: CaseIterable {
        case name
        case networks
        case methods
        case url

        var title: String {
            switch self {
            case .name:
                return R.string.localizable.walletConnectConnectionNameTitle()
            case .networks:
                return String()
            case .url:
                return R.string.localizable.walletConnectConnectionUrlTitle()
            case .methods:
                return R.string.localizable.acceptWalletConnectFieldMethodsTitle()
            }
        }

        var isExpandable: Bool {
            switch self {
            case .name, .url:
                return false
            case .methods, .networks:
                return true
            }
        }
    }
}

extension RPCServer {
    var walletConnectIconImage: ImagePublisher {
        return RPCServerImageFetcher.instance.image(server: self, iconImage: iconImage ?? R.image.tokenPlaceholderLarge()!)
    }
}
