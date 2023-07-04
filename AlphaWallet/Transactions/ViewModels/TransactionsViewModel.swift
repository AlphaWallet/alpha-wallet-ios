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
    let pullToRefreshState: AnyPublisher<Loadable<Void, Error>, Never>
}

class TransactionsViewModel {
    private let transactionsService: TransactionsService
    private let sessionsProvider: SessionsProvider

    init(transactionsService: TransactionsService, sessionsProvider: SessionsProvider) {
        self.transactionsService = transactionsService
        self.sessionsProvider = sessionsProvider
    }

    func transform(input: TransactionsViewModelInput) -> TransactionsViewModelOutput {
        let pullToRefreshState = reloadTransactions(input: input.pullToRefresh)

        let snapshot = transactionsService
            .transactions(filter: .all)
            .map { TransactionsViewModel.functional.buildSectionViewModels(for: $0) }
            .receive(on: DispatchQueue.main)
            .prepend([])
            .map { TransactionsViewModel.functional.buildSnapshot(for: $0) }

        let viewState = snapshot
            .map { TransactionsViewModel.ViewState(snapshot: $0) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, pullToRefreshState: pullToRefreshState)
    }

    private func reloadTransactions(input: AnyPublisher<Void, Never>) -> AnyPublisher<Loadable<Void, Error>, Never> {
        input.map { _ in Loadable<Void, Error>.loading }
            .delay(for: .seconds(1), scheduler: RunLoop.main)
            .handleEvents(receiveOutput: { _ in
                //TODO: implement reloading transactions, not it reloads only when its updated in db
            })
            .map { _ in Loadable<Void, Error>.done(()) }
            .share()
            .eraseToAnyPublisher()
    }

    func buildCellViewModel(for transactionRow: TransactionRow) -> TransactionRowCellViewModel? {
        guard let session = sessionsProvider.session(for: transactionRow.server) else { return nil }

        return .init(transactionRow: transactionRow, blockNumberProvider: session.blockNumberProvider, wallet: session.account)
    }
}

extension TransactionsViewModel {
    class DataSource: UITableViewDiffableDataSource<TransactionsViewModel.Section, TransactionRow> {}
    typealias Snapshot = NSDiffableDataSourceSnapshot<TransactionsViewModel.Section, TransactionRow>
    typealias Section = String
    enum functional {}

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

    fileprivate static func buildSectionViewModels(for transactions: [Transaction]) -> [TransactionsViewModel.SectionViewModel] {
        //Uses NSMutableArray instead of Swift array for performance. Really slow when dealing with 10k events, which is hardly a big wallet
        var newItems: [String: NSMutableArray] = [:]
        for transaction in transactions {
            let date = formatter.string(from: transaction.date)
            let currentItems = newItems[date] ?? .init()
            currentItems.add(transaction)
            newItems[date] = currentItems
        }
        let tuple = newItems.map { each in
            (date: each.key, transactions: (each.value as? [Transaction] ?? []).sorted { $0.date > $1.date })
        }
        let collapsedTransactions: [(date: String, transactions: [Transaction])] = tuple.sorted { (o1, o2) -> Bool in
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
                    //NOTE: already stored localized operations might be duplicated, that could cause crash when building datasource snapshot, caught few times
                    //apply .uniqued() to remove duplicates, updated code to filter operations when creating transaction object.
                    items.append(contentsOf: each.localizedOperations.uniqued().map { .item(transaction: each, operation: $0) })
                }
            }

            return (date: date, transactionRows: items.uniqued())
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
