//
//  SelectSwapToolViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct SelectSwapToolViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let disappear: AnyPublisher<Void, Never>
    let selection: AnyPublisher<SelectSwapToolViewModel.SwapToolSelection, Never>
}

struct SelectSwapToolViewModelOutput {
    let viewState: AnyPublisher<SelectSwapToolViewModel.ViewState, Never>
}

final class SelectSwapToolViewModel {
    private var storage: SwapToolStorage & SwapRouteStorage
    private var selectedTools: [SwapTool] = []
    private var cancelable = Set<AnyCancellable>()

    init(storage: SwapToolStorage & SwapRouteStorage) {
        self.storage = storage
    }

    func transform(input: SelectSwapToolViewModelInput) -> SelectSwapToolViewModelOutput {
        let selection = input.selection
            .map { [storage] selection -> (swapTool: SwapTool, selection: SelectSwapToolViewModel.SwapToolSelection)? in
                guard let swapTool = storage.swapTool(at: selection.indexPath.row) else { return nil }
                return (swapTool, selection)
            }.prepend(nil)

        let allSupportedTools = input.willAppear
            .flatMapLatest { [storage] _ in storage.allSupportedTools }

        input.disappear
            .map { _ in return self.selectedTools }
            .sink {
                self.storage.addOrUpdate(selectedTools: $0)
                self.storage.invalidatePrefferedSwapRoute()
            }.store(in: &cancelable)

        storage.selectedTools
            .filter { !$0.isEmpty }
            .first()
            .sink { [weak self] in self?.selectedTools = $0 }
            .store(in: &cancelable)

        let viewState = Publishers.CombineLatest(allSupportedTools, selection)
            .handleEvents(receiveOutput: { self.addOrRemoveSwapTool(for: $0.1) })
            .map { toolsAndSelection -> [SelectableSwapToolTableViewCellViewModel] in
                return toolsAndSelection.0.map { swapTool in
                    return SelectableSwapToolTableViewCellViewModel(swapTool: swapTool, isSelected: self.isSelected(swapTool))
                }
            }.map { viewModels -> Snapshot in
                var snapshot = Snapshot()
                snapshot.appendSections(SelectSwapToolViewModel.Section.allCases)
                snapshot.appendItems(viewModels)

                return snapshot
            }.map { SelectSwapToolViewModel.ViewState(title: "Preffered Exchanges".uppercased(), snapshot: $0) }

        return .init(viewState: viewState.eraseToAnyPublisher())
    }

    private func addOrRemoveSwapTool(for selection: (swapTool: SwapTool, selection: SelectSwapToolViewModel.SwapToolSelection)?) {
        guard let selection = selection else { return }

        switch selection.selection {
        case .deselect:
            delete(selectedTool: selection.swapTool)
        case .select:
            add(selectedTool: selection.swapTool)
        }
    }

    private func isSelected(_ tool: SwapTool) -> Bool {
        return selectedTools.contains(tool)
    }

    private func add(selectedTool swapTool: SwapTool) {
        var selectedTools = self.selectedTools

        guard !selectedTools.contains(swapTool) else { return }
        selectedTools.append(swapTool)

        self.selectedTools = selectedTools
    }

    private func delete(selectedTool swapTool: SwapTool) {
        var selectedTools = self.selectedTools

        guard selectedTools.count > 1 else { return }
        selectedTools.removeAll(where: { $0 == swapTool })

        self.selectedTools = selectedTools
    }
}

extension SelectSwapToolViewModel {
    class DataSource: UITableViewDiffableDataSource<SelectSwapToolViewModel.Section, SelectableSwapToolTableViewCellViewModel> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<SelectSwapToolViewModel.Section, SelectableSwapToolTableViewCellViewModel>

    enum Section: Int, Hashable, CaseIterable {
        case tools
    }

    enum SwapToolSelection {
        case select(IndexPath)
        case deselect(IndexPath)

        var indexPath: IndexPath {
            switch self {
            case .select(let indexPath):
                return indexPath
            case .deselect(let indexPath):
                return indexPath
            }
        }
    }

    struct ViewState {
        let title: String
        let snapshot: Snapshot
    }
}
