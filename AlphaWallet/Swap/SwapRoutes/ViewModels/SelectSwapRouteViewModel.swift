//
//  SelectSwapRouteViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.09.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct SelectSwapRouteViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let selection: AnyPublisher<IndexPath, Never>
}

struct SelectSwapRouteViewModelOutput {
    let viewState: AnyPublisher<SelectSwapRouteViewModel.ViewState, Never>
}

final class SelectSwapRouteViewModel {
    private var storage: SwapRouteStorage
    private var cancelable = Set<AnyCancellable>()

    lazy var summaryViewModel: SwapRouteSummaryViewModel = {
        SwapRouteSummaryViewModel(route: storage.swapRoutes.map { $0.first }.eraseToAnyPublisher())
    }()

    init(storage: SwapRouteStorage) {
        self.storage = storage
    }

    func transform(input: SelectSwapRouteViewModelInput) -> SelectSwapRouteViewModelOutput {
        let selection = routeSelection(input: input.selection)

        let viewState = Publishers.Merge(input.willAppear, selection)
            .flatMapLatest { [storage] _ in storage.swapRoutes }
            .map { routes -> [SelectableSwapRouteTableViewCellViewModel] in
                return routes.map { return .init(swapRoute: $0, isSelected: self.isSelected($0)) }
            }.map { self.buildSnapshot(viewModels: $0) }
            .map { SelectSwapRouteViewModel.ViewState(title: "Select Route".uppercased(), snapshot: $0) }

        return .init(viewState: viewState.eraseToAnyPublisher())
    }

    private func routeSelection(input selection: AnyPublisher<IndexPath, Never>) -> AnyPublisher<Void, Never> {
        return selection
            .map { [storage] indexPath -> SwapRoute? in storage.swapRoute(at: indexPath.row) }
            .filter { route in
                guard let route = route else { return true }
                return !self.isSelected(route)
            }.handleEvents(receiveOutput: { [weak self] in self?.set(prefferedSwapRoute: $0) })
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    private func buildSnapshot(viewModels: [SelectableSwapRouteTableViewCellViewModel]) -> Snapshot {
        var snapshot = Snapshot()
        snapshot.appendSections(SelectSwapRouteViewModel.Section.allCases)
        snapshot.appendItems(viewModels)

        return snapshot
    }

    private func set(prefferedSwapRoute value: SwapRoute?) {
        guard let value = value else { return }
        storage.set(prefferedSwapRoute: value)
    }

    private func isSelected(_ swapRoute: SwapRoute) -> Bool {
        return storage.isPreffered(swapRoute)
    }
}

extension SelectSwapRouteViewModel {
    class DataSource: UITableViewDiffableDataSource<SelectSwapRouteViewModel.Section, SelectableSwapRouteTableViewCellViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<SelectSwapRouteViewModel.Section, SelectableSwapRouteTableViewCellViewModel>

    enum Section: Int, Hashable, CaseIterable {
        case routes
    }

    struct ViewState {
        let title: String
        let snapshot: Snapshot
    }
}
