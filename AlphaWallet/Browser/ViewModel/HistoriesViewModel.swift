// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import AlphaWalletFoundation
import Combine

struct BrowserHistoryViewModelInput {
    let deleteRecord: AnyPublisher<BrowserHistoryViewModel.DeleteRecordAction, Never>
}

struct BrowserHistoryViewModelOutput {
    let viewState: AnyPublisher<BrowserHistoryViewModel.ViewState, Never>
}

class BrowserHistoryViewModel {
    private let browserHistoryStorage: BrowserHistoryStorage
    private var cancelable = Set<AnyCancellable>()

    init(browserHistoryStorage: BrowserHistoryStorage) {
        self.browserHistoryStorage = browserHistoryStorage
    }

    func transform(input: BrowserHistoryViewModelInput) -> BrowserHistoryViewModelOutput {
        input.deleteRecord
            .sink { [browserHistoryStorage] action in
                switch action {
                case .record(let record):
                    browserHistoryStorage.delete(record: record)
                case .all:
                    browserHistoryStorage.deleteAllRecords()
                }
            }.store(in: &cancelable)

        let snapshot = browserHistoryStorage.historiesChangeset
            .map { changeSet -> [BrowserHistoryRecord] in
                switch changeSet {
                case .initial(let results): return Array(results)
                case .error: return []
                case .update(let results, _, _, _): return Array(results)
                }
            }.map { $0.map { BrowserHistoryCellViewModel(history: $0) } }
            .map { self.buildSnapshot(for: $0) }

        let viewState = snapshot
            .map { BrowserHistoryViewModel.ViewState(snapshot: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildSnapshot(for viewModels: [BrowserHistoryCellViewModel]) -> BrowserHistoryViewModel.Snapshot {
        var snapshot = BrowserHistoryViewModel.Snapshot()
        snapshot.appendSections([.history])
        snapshot.appendItems(viewModels, toSection: .history)

        return snapshot
    }
}

extension BrowserHistoryViewModel {
    typealias Snapshot = NSDiffableDataSourceSnapshot<BrowserHistoryViewModel.Section, BrowserHistoryCellViewModel>
    typealias DataSource = UITableViewDiffableDataSource<BrowserHistoryViewModel.Section, BrowserHistoryCellViewModel>

    enum Section: Int, CaseIterable {
        case history
    }

    enum DeleteRecordAction {
        case record(BrowserHistoryRecord)
        case all
    }

    struct ViewState {
        let snapshot: BrowserHistoryViewModel.Snapshot
        let animatingDifferences: Bool = false
    }
}
