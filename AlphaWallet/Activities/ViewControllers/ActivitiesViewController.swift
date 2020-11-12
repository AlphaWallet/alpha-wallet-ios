// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt
import StatefulViewController

protocol ActivitiesViewControllerDelegate: class {
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
    func didPressTransaction(transaction: Transaction, in viewController: ActivitiesViewController)
}

class ActivitiesViewController: UIViewController {
    private var viewModel: ActivitiesViewModel
    private let wallet: AlphaWallet.Address
    private let sessions: ServerDictionary<WalletSession>
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let tableView = UITableView(frame: .zero, style: .grouped)

    var paymentType: PaymentFlow?
    weak var delegate: ActivitiesViewControllerDelegate?

    init(viewModel: ActivitiesViewModel, wallet: AlphaWallet.Address, sessions: ServerDictionary<WalletSession>, tokensStorages: ServerDictionary<TokensDataStore>) {
        self.viewModel = viewModel
        self.wallet = wallet
        self.sessions = sessions
        self.tokensStorages = tokensStorages
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.activityTabbarItemTitle()

        view.backgroundColor = self.viewModel.backgroundColor

        tableView.register(ActivityViewCell.self)
        tableView.register(DefaultActivityItemViewCell.self)
        tableView.register(TransactionViewCell.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = viewModel.backgroundColor
        tableView.estimatedRowHeight = TokensCardViewController.anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10
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
        NSLayoutConstraint.activate([
            title.anchorsConstraint(to: container, edgeInsets: .init(top: 18, left: 20, bottom: 16, right: 0))
        ])
        return container
    }

    private func createPseudoActivity(fromTransaction transaction: Transaction) -> Activity? {
        let token: TokenObject
        if transaction.operation == nil {
            token = TokensDataStore.etherToken(forServer: transaction.server)
        } else {
            let tokenPendingTransfer: TokenObject?
            switch (transaction.state, transaction.operation?.operationType) {
            case (.pending, .erc20TokenTransfer), (.pending, .erc721TokenTransfer), (.pending, .erc875TokenTransfer):
                tokenPendingTransfer = transaction.operation?.contractAddress.flatMap { tokensStorages[transaction.server].token(forContract: $0) }
                    //Explicitly listing out combinations so future changes to enums will be caught by compiler
            case (.pending, .nativeCurrencyTokenTransfer), (.pending, .unknown), (.pending, nil):
                tokenPendingTransfer = nil
            case (.unknown, _), (.error, _), (.failed, _), (.completed, _):
                tokenPendingTransfer = nil
            }
            if let t = tokenPendingTransfer {
                token = t
            } else {
                return nil
            }
        }

        let activityName: String
        if wallet.sameContract(as: transaction.from) {
            activityName = "sent"
        } else {
            activityName = "received"
        }
        var cardAttributes = [AttributeId: AssetInternalValue]()
        cardAttributes["symbol"] = .string(transaction.server.symbol)

        if let operation = transaction.operation, let symbol = operation.symbol, let value = BigUInt(operation.value) {
            cardAttributes["amount"] = .uint(value)
        } else {
            if let value = BigUInt(transaction.value) {
                cardAttributes["amount"] = .uint(value)
            }
        }

        if let value = AlphaWallet.Address(string: transaction.from) {
            cardAttributes["from"] = .address(value)
        }

        if let toString = transaction.operation?.to, let to = AlphaWallet.Address(string: toString) {
            cardAttributes["to"] = .address(to)
        } else {
            if let value = AlphaWallet.Address(string: transaction.to) {
                cardAttributes["to"] = .address(value)
            }
        }

        var timestamp: GeneralisedTime = .init()
        timestamp.date = transaction.date
        cardAttributes["timestamp"] = .generalisedTime(timestamp)
        let state: Activity.State
        switch transaction.state {
        case .pending:
            state = .pending
        case .completed:
            state = .completed
        case .error, .failed:
            state = .failed
        //TODO we don't need the other states at the moment
        case .unknown:
            state = .completed
        }
        return .init(
                //We only use this ID for refreshing the display of specific activity, since the display for ETH send/receives don't ever need to be refreshed, just need a number that don't clash with other activities
                id: transaction.blockNumber + 10000000,
                tokenObject: token,
                server: transaction.server,
                name: activityName,
                eventName: activityName,
                blockNumber: transaction.blockNumber,
                transactionId: transaction.id,
                transactionIndex: transaction.transactionIndex,
                //We don't use this for transactions, so it's ok
                logIndex: 0,
                date: transaction.date,
                values: (token: .init(), card: cardAttributes),
                view: (html: "", style: ""),
                itemView: (html: "", style: ""),
                isBaseCard: true,
                state: state
        )
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
            if let activity = createPseudoActivity(fromTransaction: transaction) {
                delegate?.didPressActivity(activity: activity, in: self)
            } else {
                delegate?.didPressTransaction(transaction: transaction, in: self)
            }
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

extension ActivitiesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.item(for: indexPath.row, section: indexPath.section)
        switch item {
        case .activity(let activity):
            switch activity.nativeViewType {
            case .erc20Received, .erc20Sent, .erc20OwnerApproved, .erc20ApprovalObtained, .erc721Received, .erc721Sent, .erc721OwnerApproved, .erc721ApprovalObtained, .nativeCryptoSent, .nativeCryptoReceived:
                let cell: DefaultActivityItemViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity))
                return cell
            case .none:
                let cell: ActivityViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity))
                return cell
            }
        case .transaction(let transaction):
            if let activity = createPseudoActivity(fromTransaction: transaction) {
                let cell: DefaultActivityItemViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity))
                return cell
            } else {
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
