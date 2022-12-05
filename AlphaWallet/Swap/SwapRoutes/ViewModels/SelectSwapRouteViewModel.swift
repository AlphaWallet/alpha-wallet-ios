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
        let selection = input.selection
            .map { [storage] indexPath -> SwapRoute? in storage.swapRoute(at: indexPath.row) }
            .handleEvents(receiveOutput: { [weak self] in self?.set(prefferedSwapRoute: $0) })
            .prepend(nil)

        let swapRoutes = input.willAppear
            .flatMapLatest { [storage] _ in storage.swapRoutes }

        let viewState = Publishers.CombineLatest(swapRoutes, selection)
            .map { routes -> [SelectableSwapRouteTableViewCellViewModel] in
                return routes.0.map { return .init(swapRoute: $0, isSelected: self.isSelected($0)) }
            }.map { viewModels -> Snapshot in
                var snapshot = Snapshot()
                snapshot.appendSections(SelectSwapRouteViewModel.Section.allCases)
                snapshot.appendItems(viewModels)

                return snapshot
            }.map { SelectSwapRouteViewModel.ViewState(title: "Select Route".uppercased(), snapshot: $0) }

        return .init(viewState: viewState.eraseToAnyPublisher())
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
