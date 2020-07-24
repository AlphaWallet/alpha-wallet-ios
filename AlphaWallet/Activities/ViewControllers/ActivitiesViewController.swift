// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import StatefulViewController

protocol ActivitiesViewControllerDelegate: class {
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
    //TODO fix for activities: remove to support transactions appearing in Activity tab properly
    func didPressTransaction(transaction: Transaction, in viewController: ActivitiesViewController)
}

class ActivitiesViewController: UIViewController {
    private var viewModel: ActivitiesViewModel
    private let sessions: ServerDictionary<WalletSession>
    private let tableView = UITableView(frame: .zero, style: .grouped)

    var paymentType: PaymentFlow?
    weak var delegate: ActivitiesViewControllerDelegate?

    init(viewModel: ActivitiesViewModel, sessions: ServerDictionary<WalletSession>) {
        self.viewModel = viewModel
        self.sessions = sessions
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.activityTabbarItemTitle()

        view.backgroundColor = self.viewModel.backgroundColor

        tableView.register(ActivityViewCell.self)
        tableView.register(TransactionViewCell.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = viewModel.backgroundColor
        tableView.estimatedRowHeight = TokensCardViewController.anArbitaryRowHeightSoAutoSizingCellsWorkIniOS10
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view),
        ])

        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
        })
        loadingView = LoadingView()
        //TODO move into StateViewModel once this change is global
        if let loadingView = loadingView as? LoadingView {
            loadingView.backgroundColor = Colors.appGrayLabel
            loadingView.label.textColor = Colors.appWhite
            loadingView.loadingIndicator.color = Colors.appWhite
            loadingView.label.font = Fonts.regular(size: 18)
        }
        //TODO empty view
        //emptyView = {
        //    let view = TransactionsEmptyView()
        //    return view
        //}()
    }

    func configure(viewModel: ActivitiesViewModel) {
        self.viewModel = viewModel
        tableView.reloadData()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
        if section == 0 {
            NSLayoutConstraint.activate([
                title.anchorsConstraint(to: container, edgeInsets: .init(top: 18, left: 20, bottom: 16, right: 0))
            ])
        } else {
            NSLayoutConstraint.activate([
                title.anchorsConstraint(to: container, edgeInsets: .init(top: 4, left: 20, bottom: 16, right: 0))
            ])
        }
        return container
    }
}

extension ActivitiesViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfSections > 0
    }
}

extension ActivitiesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true )
        let item = viewModel.item(for: indexPath.row, section: indexPath.section)
        switch item {
        case .activity(let activity):
            delegate?.didPressActivity(activity: activity, in: self)
        case .transaction(let transaction):
            delegate?.didPressTransaction(transaction: transaction, in: self)
        }
    }
}

extension ActivitiesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.item(for: indexPath.row, section: indexPath.section)

        switch item {
        case .activity(let activity):
            let cell: ActivityViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(activity: activity))
            return cell
        case .transaction(let transaction):
            let cell: TransactionViewCell = tableView.dequeueReusableCell(for: indexPath)
            let session = sessions[transaction.server]
            cell.configure(viewModel: .init(
                    transaction: transaction,
                    chainState: session.chainState,
                    currentWallet: session.account,
                    server: transaction.server
            )
            )
            return cell
        }
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return headerView(for: section)
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    }
}
