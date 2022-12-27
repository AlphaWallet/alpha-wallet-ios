// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine

struct TransactionsViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let pullToRefresh: AnyPublisher<Void, Never>
}

struct TransactionsViewModelOutput {
    let viewState: AnyPublisher<TransactionsViewModel.ViewState, Never>
    let pullToRefreshState: AnyPublisher<TokensViewModel.RefreshControlState, Never>
}

class TransactionsViewModel {
    private let transactionsService: TransactionsService
    private let sessions: ServerDictionary<WalletSession>

    init(transactionsService: TransactionsService, sessions: ServerDictionary<WalletSession>) {
        self.transactionsService = transactionsService
        self.sessions = sessions
    }

    func transform(input: TransactionsViewModelInput) -> TransactionsViewModelOutput {
        let beginLoading = input.pullToRefresh.map { _ in TokensViewModel.PullToRefreshState.beginLoading }
        let loadingHasEnded = beginLoading.delay(for: .seconds(2), scheduler: RunLoop.main)
            .map { _ in TokensViewModel.PullToRefreshState.endLoading }

        let fakePullToRefreshState = Just<TokensViewModel.PullToRefreshState>(TokensViewModel.PullToRefreshState.idle)
            .merge(with: beginLoading, loadingHasEnded)
            .compactMap { state -> TokensViewModel.RefreshControlState? in
                switch state {
                case .idle: return nil
                case .endLoading: return .endLoading
                case .beginLoading: return .beginLoading
                }
            }.eraseToAnyPublisher()

        let snapshot = transactionsService
            .transactionsChangeset
            .map { TransactionsViewModel.functional.buildSectionViewModels(for: $0) }
            .receive(on: DispatchQueue.main)
            .prepend([])
            .map { TransactionsViewModel.functional.buildSnapshot(for: $0) }

        let viewState = snapshot
            .map { TransactionsViewModel.ViewState(snapshot: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, pullToRefreshState: fakePullToRefreshState)
    }

    func buildCellViewModel(for transactionRow: TransactionRow) -> TransactionRowCellViewModel {
        let session = sessions[transactionRow.server]
        return .init(transactionRow: transactionRow, blockNumberProvider: session.blockNumberProvider, wallet: session.account)
    }
}

extension TransactionsViewModel {
    class DataSource: UITableViewDiffableDataSource<TransactionsViewModel.Section, TransactionRow> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<TransactionsViewModel.Section, TransactionRow>
    typealias Section = String
    class functional {}

    typealias SectionViewModel = (date: String, transactionRows: [TransactionRow])

    struct ViewState {
        let title: String = R.string.localizable.transactionsTabbarItemTitle()
        let animatingDifferences: Bool = false
        let snapshot: Snapshot
    }
}

extension TransactionsViewModel.functional {
    private static var formatter: DateFormatter {
        return Date.formatter(with: "dd MMM yyyy")
    }

    fileprivate static func buildSnapshot(for viewModels: [TransactionsViewModel.SectionViewModel]) -> TransactionsViewModel.Snapshot {
        var snapshot = NSDiffableDataSourceSnapshot<TransactionsViewModel.Section, TransactionRow>()
        let sections = viewModels.map { dateString(for: $0.date) }
        snapshot.appendSections(sections)
        for each in viewModels {
            snapshot.appendItems(each.transactionRows, toSection: dateString(for: each.date))
        }

        return snapshot
    }

    fileprivate static func buildSectionViewModels(for transactions: [TransactionInstance]) -> [TransactionsViewModel.SectionViewModel] {
        //Uses NSMutableArray instead of Swift array for performance. Really slow when dealing with 10k events, which is hardly a big wallet
        var newItems: [String: NSMutableArray] = [:]
        for transaction in transactions {
            let date = formatter.string(from: transaction.date)
            let currentItems = newItems[date] ?? .init()
            currentItems.add(transaction)
            newItems[date] = currentItems
        }
        let tuple = newItems.map { each in
            (date: each.key, transactions: (each.value as? [TransactionInstance] ?? []).sorted { $0.date > $1.date })
        }
        let collapsedTransactions: [(date: String, transactions: [TransactionInstance])] = tuple.sorted { (o1, o2) -> Bool in
            guard let d1 = formatter.date(from: o1.date), let d2 = formatter.date(from: o2.date) else {
                return false
            }
            return d1 > d2
        }

        return collapsedTransactions.map { date, transactions in
            var items: [TransactionRow] = .init()
            for each in transactions {
                if each.localizedOperations.isEmpty {
                    items.append(.standalone(each))
                } else if each.localizedOperations.count == 1, each.value == "0" {
                    items.append(.standalone(each))
                } else {
                    items.append(.group(each))
                    items.append(contentsOf: each.localizedOperations.map { .item(transaction: each, operation: $0) })
                }
            }

            return (date: date, transactionRows: items)
        }
    }

    fileprivate static func dateString(for value: String) -> String {
        guard let date = formatter.date(from: value) else { return .init() }

        if NSCalendar.current.isDateInToday(date) {
            return R.string.localizable.today().localizedUppercase
        }
        if NSCalendar.current.isDateInYesterday(date) {
            return R.string.localizable.yesterday().localizedUppercase
        }

        return value.localizedUppercase
    }
}
