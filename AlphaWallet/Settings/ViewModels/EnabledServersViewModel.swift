// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletCore
import AlphaWalletFoundation
import Combine

struct EnabledServersViewModelInput {
    let selection: AnyPublisher<RPCServer, Never>
    let enableTestnet: AnyPublisher<Bool, Never>
    let deleteCustomRpc: AnyPublisher<CustomRPC, Never>
    let reload: AnyPublisher<Void, Never>
}

struct EnabledServersViewModelOutput {
    let viewState: AnyPublisher<EnabledServersViewModel.ViewState, Never>
}

class EnabledServersViewModel {
    private let restartHandler: RestartQueueHandler
    private var serversSelectedInPreviousMode: [RPCServer]?
    private let serversProvider: ServersProvidable
    private var cancellable = Set<AnyCancellable>()
    private let selectedServers: CurrentValueSubject<[RPCServer], Never>

    init(selectedServers: [RPCServer],
         restartHandler: RestartQueueHandler,
         serversProvider: ServersProvidable) {

        self.serversProvider = serversProvider
        self.selectedServers = .init(selectedServers)
        self.restartHandler = restartHandler
    }

    func transform(input: EnabledServersViewModelInput) -> EnabledServersViewModelOutput {
        input.selection
            .sink { [weak self] in self?.toggleSelection(server: $0) }
            .store(in: &cancellable)

        input.reload
            .sink { [weak self] _ in self?.reloadServers() }
            .store(in: &cancellable)

        input.deleteCustomRpc
            .sink { [weak self] in self?.delete(customRpc: $0) }
            .store(in: &cancellable)

        let testnetEnabled = testnetEnabled(input: input.enableTestnet)
        let servers = serversProvider.enabledServersPublisher
            .map { _ in EnabledServersCoordinator.serversOrdered }
            .map { servers -> [RPCServer] in servers.uniqued() }

        let sections = Publishers.CombineLatest3(testnetEnabled, servers, selectedServers)
            .map { testnetsEnabled, servers, _ -> (mainnets: [RPCServer], testnets: [RPCServer]) in
                let mainnets = Array(servers.filter { !$0.isTestnet })
                let testnets = Array(testnetsEnabled ? servers.filter { $0.isTestnet } : [])

                return (mainnets: mainnets, testnets: testnets)
            }

        let title = selectedServers
            .map { R.string.localizable.settingsEnabledNetworksButtonTitle("(\($0.count))") }

        let viewState = Publishers.CombineLatest(sections, title)
            .map { data, title in
                let mainnets = data.mainnets.map { self.buildViewModel(server: $0) }
                let testnets = data.testnets.map { self.buildViewModel(server: $0) }

                return ViewState(
                    title: title,
                    snapshot: self.buildSnapshot(
                        for: [
                            SectionViewModel(section: .mainnet, isEnabled: true, viewModels: mainnets),
                            SectionViewModel(section: .testnet, isEnabled: !testnets.isEmpty, viewModels: testnets)
                        ]))
            }

        return .init(viewState: viewState.eraseToAnyPublisher())
    }

    private func buildViewModel(server: RPCServer) -> ServerImageViewModel {
        return ServerImageViewModel(
            server: .server(server),
            isSelected: selectedServers.value.contains(server),
            isAvailableToSelect: !server.isDeprecated,
            warningImage: server.isDeprecated ? R.image.gasWarning() : nil)
    }

    private func testnetEnabled(input: AnyPublisher<Bool, Never>) -> AnyPublisher<Bool, Never> {
        let usersInput = input
            .handleEvents(receiveOutput: { [weak self] in self?.enableTestnet($0) })

        let isAnyOfSelectedServersIsTestnet = serversProvider.enabledServersPublisher
            .map { $0.contains(where: { $0.isTestnet }) }

        return Publishers.Merge(isAnyOfSelectedServersIsTestnet, usersInput)
            .eraseToAnyPublisher()
    }

    private func enableTestnet(_ enabled: Bool) {
        if let previousMode = serversSelectedInPreviousMode {
            serversSelectedInPreviousMode = selectedServers.value
            selectedServers.value = previousMode
        } else {
            serversSelectedInPreviousMode = selectedServers.value

            if enabled {
                selectedServers.value = Array(Set(selectedServers.value + Constants.defaultEnabledTestnetServers))
            } else {
                selectedServers.value = selectedServers.value.filter { !$0.isTestnet }
            }
        }
    }

    private func toggleSelection(server: RPCServer) {
        let servers: [RPCServer]
        if selectedServers.value.contains(server) {
            servers = selectedServers.value - [server]
        } else {
            servers = selectedServers.value + [server]
        }
        selectedServers.value = servers
    }

    func reloadServers() {
        let servers = selectedServers.value
        //Defensive. Shouldn't allow no server to be selected
        guard !servers.isEmpty else { return }

        let isUnchanged = Set(serversProvider.enabledServers) == Set(servers)
        if isUnchanged {
            //no-op
        } else {
            restartHandler.add(.reloadServers(servers))
        }

        restartHandler.processTasks()
    }

    private func delete(customRpc: CustomRPC) {
        restartHandler.add(.removeServer(customRpc))

        restartHandler.processTasks()
    }

    private func buildSnapshot(for viewModels: [EnabledServersViewModel.SectionViewModel]) -> EnabledServersViewModel.Snapshot {
        var snapshot = NSDiffableDataSourceSnapshot<EnabledServersViewModel.SectionViewModel, ServerImageViewModel>()
        let sections = viewModels
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.viewModels, toSection: each)
        }

        return snapshot
    }
}

extension EnabledServersViewModel.SectionViewModel: Hashable {}
extension EnabledServersViewModel.Section: Hashable {}

extension EnabledServersViewModel {
    class DataSource: UITableViewDiffableDataSource<EnabledServersViewModel.SectionViewModel, ServerImageViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<EnabledServersViewModel.SectionViewModel, ServerImageViewModel>

    struct ViewState {
        let title: String
        let snapshot: Snapshot
    }

    struct SectionViewModel {
        let section: Section
        let isEnabled: Bool
        let viewModels: [ServerImageViewModel]
    }

    enum Section {
        case testnet
        case mainnet
    }

    enum Mode {
        case testnet
        case mainnet

        var headerText: String {
            switch self {
            case .testnet:
                return R.string.localizable.settingsEnabledNetworksTestnet().uppercased()
            case .mainnet:
                return R.string.localizable.settingsEnabledNetworksMainnet().uppercased()
            }
        }
    }
}
