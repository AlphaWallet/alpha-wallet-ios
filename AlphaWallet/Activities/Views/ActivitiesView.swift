//
//  ActivitiesView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.08.2021.
//

import UIKit
import BigInt
import StatefulViewController
import AlphaWalletFoundation

protocol ActivitiesViewDelegate: AnyObject {
    func didPressActivity(activity: Activity, in view: ActivitiesView)
    func didPressTransaction(transaction: Transaction, in view: ActivitiesView)
}

class ActivitiesView: UIView {
    private var viewModel: ActivitiesViewModel
    private let sessionsProvider: SessionsProvider
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(ActivityViewCell.self)
        tableView.register(DefaultActivityItemViewCell.self)
        tableView.register(TransactionTableViewCell.self)
        tableView.register(GroupActivityViewCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = DataEntry.Metric.anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10

        return tableView
    }()
    private let keystore: Keystore
    private let wallet: Wallet
    private let analytics: AnalyticsLogger
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenImageFetcher: TokenImageFetcher

    weak var delegate: ActivitiesViewDelegate?

    init(analytics: AnalyticsLogger,
         keystore: Keystore,
         wallet: Wallet,
         viewModel: ActivitiesViewModel,
         sessionsProvider: SessionsProvider,
         assetDefinitionStore: AssetDefinitionStore,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = viewModel
        self.sessionsProvider = sessionsProvider
        self.keystore = keystore
        self.wallet = wallet
        self.analytics = analytics
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: self)
        ])

        emptyView = EmptyView.activitiesEmptyView()
    }

    func resetStatefulStateToReleaseObjectToAvoidMemoryLeak() {
        // NOTE: Stateful lib set to object state machine that later causes ref cycle when applying it to view
        // here we release all associated objects to release state machine
        // this method is called while parent's view deinit get called
        objc_removeAssociatedObjects(self)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func reloadData() {
        tableView.reloadData()
    }

    func configure(viewModel: ActivitiesViewModel) {
        self.viewModel = viewModel
    }

    func applySearch(keyword: String?) {
        viewModel.filter(.keyword(keyword))

        reloadData()
    }
}

extension ActivitiesView: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfSections > 0
    }
}

extension ActivitiesView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true )
        switch viewModel.item(for: indexPath.row, section: indexPath.section) {
        case .parentTransaction:
            break
        case .childActivity(_, activity: let activity):
            delegate?.didPressActivity(activity: activity, in: self)
        case .childTransaction(let transaction, _, let activity):
            if let activity = activity {
                delegate?.didPressActivity(activity: activity, in: self)
            } else {
                delegate?.didPressTransaction(transaction: transaction, in: self)
            }
        case .standaloneTransaction(transaction: let transaction, let activity):
            if let activity = activity {
                delegate?.didPressActivity(activity: activity, in: self)
            } else {
                delegate?.didPressTransaction(transaction: transaction, in: self)
            }
        case .standaloneActivity(activity: let activity):
            delegate?.didPressActivity(activity: activity, in: self)
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch viewModel.item(for: indexPath.row, section: indexPath.section) {
        case .parentTransaction:
            return nil
        case .childActivity, .childTransaction, .standaloneTransaction, .standaloneActivity:
            return indexPath
        }
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}

extension ActivitiesView: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    private func setupTokenScriptRendererViewForCellOnce(cell: ActivityViewCell) {
        guard cell.tokenScriptRendererView == nil else { return }

        let tokenScriptRendererView: TokenInstanceWebView = {
            //TODO server value doesn't matter since we will change it later. But we should improve this
            let webView = TokenInstanceWebView(server: .main, wallet: wallet, assetDefinitionStore: assetDefinitionStore)
            //TODO needed? Seems like scary, performance-wise
            //webView.delegate = self
            return webView
        }()

        cell.setupTokenScriptRendererView(tokenScriptRendererView)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.item(for: indexPath.row, section: indexPath.section) {
        case .parentTransaction(_, isSwap: let isSwap, _):
            let cell: GroupActivityViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(groupType: isSwap ? .swap : .unknown))
            return cell
        case .childActivity(_, activity: let activity):
            let activity: Activity = {
                var a = activity
                a.rowType = .item
                return a
            }()
            switch activity.nativeViewType {
            case .erc20Received, .erc20Sent, .erc20OwnerApproved, .erc20ApprovalObtained, .erc721Received, .erc721Sent, .erc721OwnerApproved, .erc721ApprovalObtained, .nativeCryptoSent, .nativeCryptoReceived:
                let cell: DefaultActivityItemViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity, tokenImageFetcher: tokenImageFetcher))
                return cell
            case .none:
                let cell: ActivityViewCell = tableView.dequeueReusableCell(for: indexPath)
                setupTokenScriptRendererViewForCellOnce(cell: cell)
                cell.configure(viewModel: .init(activity: activity))
                return cell
            }
        case .childTransaction(transaction: let transaction, operation: let operation, let activity):
            if let activity = activity {
                let cell: DefaultActivityItemViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity, tokenImageFetcher: tokenImageFetcher))
                return cell
            } else {
                let cell: TransactionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                guard let session = sessionsProvider.session(for: transaction.server) else { return UITableViewCell() }
                cell.configure(viewModel: .init(transactionRow: .item(transaction: transaction, operation: operation), blockNumberProvider: session.blockNumberProvider, wallet: session.account))
                return cell
            }
        case .standaloneTransaction(transaction: let transaction, let activity):
            if let activity = activity {
                let cell: DefaultActivityItemViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity, tokenImageFetcher: tokenImageFetcher))
                return cell
            } else {
                let cell: TransactionTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                guard let session = sessionsProvider.session(for: transaction.server) else { return UITableViewCell() }
                cell.configure(viewModel: .init(transactionRow: .standalone(transaction), blockNumberProvider: session.blockNumberProvider, wallet: session.account))
                return cell
            }
        case .standaloneActivity(activity: let activity):
            switch activity.nativeViewType {
            case .erc20Received, .erc20Sent, .erc20OwnerApproved, .erc20ApprovalObtained, .erc721Received, .erc721Sent, .erc721OwnerApproved, .erc721ApprovalObtained, .nativeCryptoSent, .nativeCryptoReceived:
                let cell: DefaultActivityItemViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity, tokenImageFetcher: tokenImageFetcher))
                return cell
            case .none:
                let cell: ActivityViewCell = tableView.dequeueReusableCell(for: indexPath)
                setupTokenScriptRendererViewForCellOnce(cell: cell)
                cell.configure(viewModel: .init(activity: activity))
                return cell
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return ActivitiesViewController.functional.headerView(for: section, viewModel: viewModel)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    }

    fileprivate func headerView(for section: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = viewModel.headerBackgroundColor
        let title = UILabel()
        title.text = viewModel.titleForHeader(in: section)
        title.sizeToFit()
        title.textColor = viewModel.headerTitleTextColor
        title.font = viewModel.headerTitleFont
        container.addSubview(title)
        title.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            title.anchorsConstraint(to: container, edgeInsets: .init(top: 18, left: 20, bottom: 16, right: 0))
        ])
        return container
    }
}
