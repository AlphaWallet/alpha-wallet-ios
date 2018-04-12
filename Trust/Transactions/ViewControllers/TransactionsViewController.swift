// Copyright SIX DAY LLC. All rights reserved.

import UIKit
import APIKit
import JSONRPCKit
import StatefulViewController
import Result
import TrustKeystore

protocol TransactionsViewControllerDelegate: class {
    func didPressSend(in viewController: TransactionsViewController)
    func didPressTransaction(transaction: Transaction, in viewController: TransactionsViewController)
    func didPressDeposit(for account: Wallet, sender: UIView, in viewController: TransactionsViewController)
}

class TransactionsViewController: UIViewController {

    var viewModel: TransactionsViewModel
    var paymentType: PaymentFlow?

    let tokensStorage: TokensDataStore
    let account: Wallet

    let tableView = UITableView(frame: .zero, style: .plain)
    let refreshControl = UIRefreshControl()

    lazy var titleView: BalanceTitleView = {
        return BalanceTitleView.make(from: self.session, .ether(destination: .none))
    }()

    weak var delegate: TransactionsViewControllerDelegate?
    let dataCoordinator: TransactionDataCoordinator
    let session: WalletSession
    var actionButtonsVisibleConstraint: NSLayoutConstraint?
    var actionButtonsInVisibleConstraint: NSLayoutConstraint?
    var showActionButtons = false {
        didSet {
			reflectActionButtonsVisibility()
        }
    }

    lazy var footerView: TransactionsFooterView = {
        let footerView = TransactionsFooterView(frame: .zero)
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)
        return footerView
    }()
    let footerBar: UIView = {
        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
		return footerBar
    }()

    init(
        account: Wallet,
        dataCoordinator: TransactionDataCoordinator,
        session: WalletSession,
        tokensStorage: TokensDataStore,
        viewModel: TransactionsViewModel = TransactionsViewModel(transactions: [])
    ) {
        self.account = account
        self.dataCoordinator = dataCoordinator
        self.session = session
        self.viewModel = viewModel
        self.tokensStorage = tokensStorage
        super.init(nibName: nil, bundle: nil)

        tokensStorage.updatePrices()
        view.backgroundColor = viewModel.backgroundColor
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        tableView.rowHeight = 80
        view.addSubview(tableView)

        view.addSubview(footerBar)

		let footerViewHeight = CGFloat(60)
        footerBar.addSubview(footerView)

        actionButtonsVisibleConstraint = footerBar.heightAnchor.constraint(equalToConstant: footerViewHeight)
        actionButtonsInVisibleConstraint = footerBar.topAnchor.constraint(equalTo: footerBar.bottomAnchor)

        reflectActionButtonsVisibility()

        let separatorThickness = CGFloat(1)
        NSLayoutConstraint.activate([
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            footerView.topAnchor.constraint(equalTo: footerBar.topAnchor),
			footerView.heightAnchor.constraint(equalToConstant: footerViewHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        dataCoordinator.delegate = self
        dataCoordinator.start()

        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.addSubview(refreshControl)

        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.dataCoordinator.fetch()
        })
        loadingView = LoadingView()
        //TODO move into StateViewModel once this change is global
        if let loadingView = loadingView as? LoadingView {
            loadingView.backgroundColor = Colors.appBackground
            loadingView.label.textColor = Colors.appWhite
            loadingView.loadingIndicator.color = Colors.appWhite
            loadingView.label.font = Fonts.regular(size: 18)
        }
        emptyView = {
            let view = TransactionsEmptyView(
                onDeposit: { [unowned self] sender in
                    self.showDeposit(sender)
                }
            )
            view.isDepositAvailable = viewModel.isBuyActionAvailable
            return view
        }()

        navigationItem.titleView = titleView
        titleView.viewModel = BalanceViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        fetch()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    @objc func pullToRefresh() {
        refreshControl.beginRefreshing()
        fetch()
    }

    func fetch() {
        startLoading()
        dataCoordinator.fetch()
    }

    @objc func send() {
        delegate?.didPressSend(in: self)
    }

    func showDeposit(_ sender: UIButton) {
        delegate?.didPressDeposit(for: account, sender: sender, in: self)
    }

    func configure(viewModel: TransactionsViewModel) {
        self.viewModel = viewModel
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    fileprivate func hederView(for section: Int) -> UIView {
        let conteiner = UIView()
        conteiner.backgroundColor = viewModel.headerBackgroundColor
        let title = UILabel()
        title.text = viewModel.titleForHeader(in: section)
        title.sizeToFit()
        title.textColor = viewModel.headerTitleTextColor
        title.font = viewModel.headerTitleFont
        conteiner.addSubview(title)
        title.translatesAutoresizingMaskIntoConstraints = false
        let horConstraint = NSLayoutConstraint(item: title, attribute: .centerX, relatedBy: .equal, toItem: conteiner, attribute: .centerX, multiplier: 1.0, constant: 0.0)
        let verConstraint = NSLayoutConstraint(item: title, attribute: .centerY, relatedBy: .equal, toItem: conteiner, attribute: .centerY, multiplier: 1.0, constant: 0.0)
        let leftConstraint = NSLayoutConstraint(item: title, attribute: .left, relatedBy: .equal, toItem: conteiner, attribute: .left, multiplier: 1.0, constant: 20.0)
        conteiner.addConstraints([horConstraint, verConstraint, leftConstraint])
        return conteiner
    }

    private func reflectActionButtonsVisibility() {
        if showActionButtons {
            actionButtonsVisibleConstraint?.isActive = true
            actionButtonsInVisibleConstraint?.isActive = false
        } else {
            actionButtonsVisibleConstraint?.isActive = false
            actionButtonsInVisibleConstraint?.isActive = true
        }
    }
}

extension TransactionsViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfSections > 0
    }
}

extension TransactionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true )
        delegate?.didPressTransaction(transaction: viewModel.item(for: indexPath.row, section: indexPath.section), in: self)
    }
}

extension TransactionsViewController: TransactionDataCoordinatorDelegate {
    func didUpdate(result: Result<[Transaction], TransactionError>) {
        switch result {
        case .success(let items):
        let viewModel = TransactionsViewModel(transactions: items)
            configure(viewModel: viewModel)
            endLoading()
        case .failure(let error):
            endLoading(error: error)
        }
        tableView.reloadData()

        if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }
    }
}

extension TransactionsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let transaction = viewModel.item(for: indexPath.row, section: indexPath.section)
        let cell = TransactionViewCell(style: .default, reuseIdentifier: TransactionViewCell.identifier)
        cell.configure(viewModel: .init(
                transaction: transaction,
                config: session.config,
                chainState: session.chainState,
                currentWallet: session.account
            )
        )
        return cell
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return hederView(for: section)
    }
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    }
    //Method heightForHeaderInSection is required for iOS 10.
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
}

