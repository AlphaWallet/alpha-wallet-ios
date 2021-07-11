// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import BigInt
import StatefulViewController

protocol ActivitiesViewControllerDelegate: class {
    func didPressActivity(activity: Activity, in viewController: ActivitiesViewController)
    func didPressTransaction(transaction: TransactionInstance, in viewController: ActivitiesViewController)
}

class ActivitiesViewController: UIViewController {
    private var viewModel: ActivitiesViewModel
    private let wallet: AlphaWallet.Address
    private let sessions: ServerDictionary<WalletSession>
    private let tokensStorages: ServerDictionary<TokensDataStore>
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let searchController: UISearchController
    private var isSearchBarConfigured = false
    private var bottomConstraint: NSLayoutConstraint!
    private lazy var keyboardChecker = KeyboardChecker(self, resetHeightDefaultValue: 0, ignoreBottomSafeArea: true)

    var paymentType: PaymentFlow?
    weak var delegate: ActivitiesViewControllerDelegate?

    init(viewModel: ActivitiesViewModel, wallet: AlphaWallet.Address, sessions: ServerDictionary<WalletSession>, tokensStorages: ServerDictionary<TokensDataStore>) {
        self.viewModel = viewModel
        self.wallet = wallet
        self.sessions = sessions
        self.tokensStorages = tokensStorages
        searchController = UISearchController(searchResultsController: nil)
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.activityTabbarItemTitle()

        view.backgroundColor = self.viewModel.backgroundColor

        tableView.register(ActivityViewCell.self)
        tableView.register(DefaultActivityItemViewCell.self)
        tableView.register(TransactionViewCell.self)
        tableView.register(GroupActivityViewCell.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = viewModel.backgroundColor
        tableView.estimatedRowHeight = TokensCardViewController.anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10

        bottomConstraint = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        keyboardChecker.constraint = bottomConstraint

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
        ])
        emptyView = TransactionsEmptyView(title: R.string.localizable.activityEmpty(), image: R.image.activities_empty_list())

        setupFilteringWithKeyword()
        processSearchWithKeywords()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        keyboardChecker.viewWillAppear()
        navigationItem.largeTitleDisplayMode = .always
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //NOTE: we call it here to show empty view if needed, as the reason that we don't have manually called callback where we can handle that loaded activities
        //next time view will be updated when configure with viewModel method get called.
        endLoading()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardChecker.viewWillDisappear()
    }

    func configure(viewModel: ActivitiesViewModel) {
        self.viewModel = viewModel
        processSearchWithKeywords()

        endLoading()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLayoutSubviews() {
        configureSearchBarOnce()
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
        case .parentTransaction:
            break
        case .childActivity(_, activity: let activity):
            delegate?.didPressActivity(activity: activity, in: self)
        case .childTransaction(transaction: let transaction, operation: let operation):
            if let activity = functional.createPseudoActivity(fromTransactionRow: .item(transaction: transaction, operation: operation), tokensStorages: tokensStorages, wallet: wallet) {
                delegate?.didPressActivity(activity: activity, in: self)
            } else {
                delegate?.didPressTransaction(transaction: transaction, in: self)
            }
        case .standaloneTransaction(transaction: let transaction):
            if let activity = functional.createPseudoActivity(fromTransactionRow: .standalone(transaction), tokensStorages: tokensStorages, wallet: wallet) {
                delegate?.didPressActivity(activity: activity, in: self)
            } else {
                delegate?.didPressTransaction(transaction: transaction, in: self)
            }
        case .standaloneActivity(activity: let activity):
            delegate?.didPressActivity(activity: activity, in: self)
        }
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let item = viewModel.item(for: indexPath.row, section: indexPath.section)
        switch item {
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

extension ActivitiesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.item(for: indexPath.row, section: indexPath.section)
        switch item {
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
                cell.configure(viewModel: .init(activity: activity))
                return cell
            case .none:
                let cell: ActivityViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity))
                return cell
            }
        case .childTransaction(transaction: let transaction, operation: let operation):
            if let activity = functional.createPseudoActivity(fromTransactionRow: .item(transaction: transaction, operation: operation), tokensStorages: tokensStorages, wallet: wallet) {
                let cell: DefaultActivityItemViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity))
                return cell
            } else {
                let cell: TransactionViewCell = tableView.dequeueReusableCell(for: indexPath)
                let session = sessions[transaction.server]
                cell.configure(viewModel: .init(transactionRow: .item(transaction: transaction, operation: operation), chainState: session.chainState, currentWallet: session.account, server: transaction.server))
                return cell
            }
        case .standaloneTransaction(transaction: let transaction):
            if let activity = functional.createPseudoActivity(fromTransactionRow: .standalone(transaction), tokensStorages: tokensStorages, wallet: wallet) {
                let cell: DefaultActivityItemViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(activity: activity))
                return cell
            } else {
                let cell: TransactionViewCell = tableView.dequeueReusableCell(for: indexPath)
                let session = sessions[transaction.server]
                cell.configure(viewModel: .init(transactionRow: .standalone(transaction), chainState: session.chainState, currentWallet: session.account, server: transaction.server))
                return cell
            }
        case .standaloneActivity(activity: let activity):
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
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return functional.headerView(for: section, viewModel: viewModel)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    }
}

extension ActivitiesViewController: UISearchResultsUpdating {
    //At least on iOS 13 beta on a device. updateSearchResults(for:) is called when we set `searchController.isActive = false` to dismiss search (because user tapped on a filter), but the value of `searchController.isActive` remains `false` during the call, hence the async.
    //This behavior is not observed in iOS 12, simulator
    public func updateSearchResults(for searchController: UISearchController) {
        processSearchWithKeywords()
    }

    private func processSearchWithKeywords() {
        let keyword = searchController.searchBar.text
        viewModel.filter(.keyword(keyword))

        tableView.reloadData()
    }

}

extension ActivitiesViewController {

    private func makeSwitchToAnotherTabWorkWhileFiltering() {
        definesPresentationContext = true
    }

    private func doNotDimTableViewToReuseTableForFilteringResult() {
        searchController.dimsBackgroundDuringPresentation = false
    }

    private func wireUpSearchController() {
        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    private func fixNavigationBarAndStatusBarBackgroundColorForiOS13Dot1() {
        view.superview?.backgroundColor = viewModel.backgroundColor
    }

    private func setupFilteringWithKeyword() {
        wireUpSearchController()
        doNotDimTableViewToReuseTableForFilteringResult()
        makeSwitchToAnotherTabWorkWhileFiltering()
    }

    //Makes a difference where this is called from. Can't be too early
    private func configureSearchBarOnce() {
        guard !isSearchBarConfigured else { return }
        isSearchBarConfigured = true

        if let placeholderLabel = searchController.searchBar.firstSubview(ofType: UILabel.self) {
            placeholderLabel.textColor = Colors.lightGray
        }
        if let textField = searchController.searchBar.firstSubview(ofType: UITextField.self) {
            textField.textColor = Colors.appText
            if let imageView = textField.leftView as? UIImageView {
                imageView.image = imageView.image?.withRenderingMode(.alwaysTemplate)
                imageView.tintColor = Colors.appText
            }
        }
        //Hack to hide the horizontal separator below the search bar
        searchController.searchBar.superview?.firstSubview(ofType: UIImageView.self)?.isHidden = true
    }
}

extension ActivitiesViewController {
    class functional {}
}

extension ActivitiesViewController.functional {
    static func extractTokenAndActivityName(fromTransactionRow transactionRow: TransactionRow, tokensStorages: ServerDictionary<TokensDataStore>, wallet: AlphaWallet.Address) -> (token: TokenObject, activityName: String)? {
        enum TokenOperation {
            case nativeCryptoTransfer(TokenObject)
            case completedTransfer(TokenObject)
            case pendingTransfer(TokenObject)
            case completedErc20Approval(TokenObject)
            case pendingErc20Approval(TokenObject)

            var token: TokenObject {
                switch self {
                case .nativeCryptoTransfer(let token):
                    return token
                case .completedTransfer(let token):
                    return token
                case .pendingTransfer(let token):
                    return token
                case .completedErc20Approval(let token):
                    return token
                case .pendingErc20Approval(let token):
                    return token
                }
            }
        }

        let erc20TokenOperation: TokenOperation?
        if transactionRow.operation == nil {
            erc20TokenOperation = .nativeCryptoTransfer(TokensDataStore.etherToken(forServer: transactionRow.server))
        } else {
            switch (transactionRow.state, transactionRow.operation?.operationType) {
            case (.pending, .nativeCurrencyTokenTransfer), (.pending, .erc20TokenTransfer), (.pending, .erc721TokenTransfer), (.pending, .erc875TokenTransfer):
                erc20TokenOperation = transactionRow.operation?.contractAddress.flatMap { tokensStorages[transactionRow.server].token(forContract: $0) }.flatMap { TokenOperation.pendingTransfer($0) }
            case (.completed, .nativeCurrencyTokenTransfer), (.completed, .erc20TokenTransfer), (.completed, .erc721TokenTransfer), (.completed, .erc875TokenTransfer):
                erc20TokenOperation = transactionRow.operation?.contractAddress.flatMap { tokensStorages[transactionRow.server].token(forContract: $0) }.flatMap { TokenOperation.completedTransfer($0) }
                    //Explicitly listing out combinations so future changes to enums will be caught by compiler
            case (.pending, .erc20TokenApprove):
                erc20TokenOperation = transactionRow.operation?.contractAddress.flatMap { tokensStorages[transactionRow.server].token(forContract: $0) }.flatMap { TokenOperation.pendingErc20Approval($0) }
            case (.completed, .erc20TokenApprove):
                erc20TokenOperation = transactionRow.operation?.contractAddress.flatMap { tokensStorages[transactionRow.server].token(forContract: $0) }.flatMap { TokenOperation.completedErc20Approval($0) }
            case (.unknown, _), (.error, _), (.failed, _), (_, .unknown), (.completed, .none), (.pending, nil):
                erc20TokenOperation = .none
            }
        }
        guard let token = erc20TokenOperation?.token else { return nil }
        let activityName: String
        switch erc20TokenOperation {
        case .nativeCryptoTransfer, .completedTransfer, .pendingTransfer, .none:
            if wallet.sameContract(as: transactionRow.from) {
                activityName = "sent"
            } else {
                activityName = "received"
            }
        case .completedErc20Approval, .pendingErc20Approval:
            activityName = "ownerApproved"
        }
        return (token: token, activityName: activityName)
    }

    static func createPseudoActivity(fromTransactionRow transactionRow: TransactionRow, tokensStorages: ServerDictionary<TokensDataStore>, wallet: AlphaWallet.Address) -> Activity? {
        guard let (token, activityName) = extractTokenAndActivityName(fromTransactionRow: transactionRow, tokensStorages: tokensStorages, wallet: wallet) else { return nil }
        var cardAttributes = [AttributeId: AssetInternalValue]()
        cardAttributes["symbol"] = .string(transactionRow.server.symbol)

        if let operation = transactionRow.operation, operation.symbol != nil, let value = BigUInt(operation.value) {
            cardAttributes["amount"] = .uint(value)
        } else {
            if let value = BigUInt(transactionRow.value) {
                cardAttributes["amount"] = .uint(value)
            }
        }

        if let value = AlphaWallet.Address(string: transactionRow.from) {
            cardAttributes["from"] = .address(value)
        }

        if let toString = transactionRow.operation?.to, let to = AlphaWallet.Address(string: toString) {
            cardAttributes["to"] = .address(to)
        } else {
            if let value = AlphaWallet.Address(string: transactionRow.to) {
                cardAttributes["to"] = .address(value)
            }
        }

        var timestamp: GeneralisedTime = .init()
        timestamp.date = transactionRow.date
        cardAttributes["timestamp"] = .generalisedTime(timestamp)
        let state: Activity.State
        switch transactionRow.state {
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
        let rowType: ActivityRowType
        switch transactionRow {
        case .standalone:
            rowType = .standalone
        case .group:
            rowType = .group
        case .item:
            rowType = .item
        }
        return .init(
                //We only use this ID for refreshing the display of specific activity, since the display for ETH send/receives don't ever need to be refreshed, just need a number that don't clash with other activities
                id: transactionRow.blockNumber + 10000000,
                rowType: rowType,
                tokenObject: Activity.AssignedToken(tokenObject: token),
                server: transactionRow.server,
                name: activityName,
                eventName: activityName,
                blockNumber: transactionRow.blockNumber,
                transactionId: transactionRow.id,
                transactionIndex: transactionRow.transactionIndex,
                //We don't use this for transactions, so it's ok
                logIndex: 0,
                date: transactionRow.date,
                values: (token: .init(), card: cardAttributes),
                view: (html: "", style: ""),
                itemView: (html: "", style: ""),
                isBaseCard: true,
                state: state
        )
    }

    fileprivate static func headerView(for section: Int, viewModel: ActivitiesViewModel) -> UIView {
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
