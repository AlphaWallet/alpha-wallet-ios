import Foundation
import UIKit
import StatefulViewController
import Result
import TrustKeystore

protocol TokensViewControllerDelegate: class {
    func didPressAddToken( in viewController: UIViewController)
    func didSelect(token: TokenObject, in viewController: UIViewController)
    func didDelete(token: TokenObject, in viewController: UIViewController)
}

class TokensViewController: UIViewController {

    private let dataStore: TokensDataStore

    var viewModel: TokensViewModel = TokensViewModel(config: Config(), tokens: [], tickers: .none) {
        didSet {
            viewModel.filter = oldValue.filter
            refreshView(viewModel: viewModel)
        }
    }
    let session: WalletSession
    let account: Wallet
	let filterView = WalletFilterView()
    var importWalletView: UIView?
    var importWalletLayer = CAShapeLayer()
    var importWalletHelpBubbleView: ImportWalletHelpBubbleView?
    let tableView: UITableView
    let refreshControl = UIRefreshControl()
    weak var delegate: TokensViewControllerDelegate?

    init(session: WalletSession,
         account: Wallet,
         dataStore: TokensDataStore
    ) {
		self.session = session
        self.account = account
        self.dataStore = dataStore
        tableView = UITableView(frame: .zero, style: .plain)
        super.init(nibName: nil, bundle: nil)
        dataStore.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addToken))

        view.backgroundColor = Colors.appBackground

        filterView.delegate = self
        filterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterView)

        tableView.register(TokenViewCell.self, forCellReuseIdentifier: TokenViewCell.identifier)
        tableView.register(EthTokenViewCell.self, forCellReuseIdentifier: EthTokenViewCell.identifier)
        tableView.register(TicketTokenViewCell.self, forCellReuseIdentifier: TicketTokenViewCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            filterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterView.topAnchor.constraint(equalTo: view.topAnchor),
            filterView.bottomAnchor.constraint(equalTo: tableView.topAnchor, constant: -7),

            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
        errorView = ErrorView(onRetry: { [weak self] in
            self?.startLoading()
            self?.dataStore.fetch()
        })
        loadingView = LoadingView()
        emptyView = EmptyView(
            title: R.string.localizable.emptyViewNoTokensLabelTitle(),
            onRetry: { [weak self] in
                self?.startLoading()
                self?.dataStore.fetch()
        })
        refreshView(viewModel: viewModel)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.applyTintAdjustment()
        fetch()
    }
    @objc func pullToRefresh() {
        refreshControl.beginRefreshing()
        fetch()
    }

    func fetch() {
        self.startLoading()
        self.dataStore.fetch()
    }

    override func viewDidLayoutSubviews() {
        if let importWalletView = importWalletView {
            importWalletLayer.frame = importWalletView.bounds
            importWalletLayer.path = createImportWalletImagePath().cgPath
        }
    }

    private func reload() {
        tableView.reloadData()
        let haveData = viewModel.numberOfSections > 0 && viewModel.numberOfItems(for: 0) > 0
        if haveData {
            hideImportWalletImage()
        } else {
            showImportWalletImage()
        }
    }

    private func hideImportWalletImage() {
        importWalletView?.isHidden = true
		importWalletHelpBubbleView?.isHidden = true
    }

    private func showImportWalletImage() {
        if let importWalletView = importWalletView {
            importWalletView.isHidden = false
            return
        }
        importWalletView = UIView()
        if let importWalletView = importWalletView {
            view.addSubview(importWalletView)

            let imageView = UIImageView(image: R.image.wallet_import())

            importWalletLayer.path = createImportWalletImagePath().cgPath
            importWalletLayer.lineDashPattern = [5, 5]
            importWalletLayer.strokeColor = UIColor.white.cgColor
            importWalletLayer.fillColor = UIColor.clear.cgColor
            importWalletView.layer.addSublayer(importWalletLayer)

            let label = UILabel()
            label.textColor = .white
            label.text = R.string.localizable.aWalletImportWalletTitle()

            let stackView = [
                imageView,
                label,
            ].asStackView(axis: .vertical, spacing: 10, alignment: .center)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            importWalletView.addSubview(stackView)

            let sideMargin = CGFloat(7)
            importWalletView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                importWalletView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
                importWalletView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
                importWalletView.topAnchor.constraint(equalTo: view.topAnchor, constant: 52),
                importWalletView.heightAnchor.constraint(equalToConstant: 138),

                stackView.centerXAnchor.constraint(equalTo: importWalletView.centerXAnchor),
                stackView.centerYAnchor.constraint(equalTo: importWalletView.centerYAnchor),
            ])
        }
        importWalletHelpBubbleView = ImportWalletHelpBubbleView()
		let sideMargin = CGFloat(7)
        if let importWalletView = importWalletView, let importWalletHelpBubbleView = importWalletHelpBubbleView {
            view.addSubview(importWalletHelpBubbleView)

            NSLayoutConstraint.activate([
                importWalletHelpBubbleView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sideMargin),
                importWalletHelpBubbleView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -sideMargin),
                importWalletHelpBubbleView.topAnchor.constraint(equalTo: importWalletView.bottomAnchor, constant: 7),
            ])
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshView(viewModel: TokensViewModel) {
        title = viewModel.title
        view.backgroundColor = viewModel.backgroundColor
    }

    @objc func addToken() {
        delegate?.didPressAddToken(in: self)
    }

    private func createImportWalletImagePath() -> UIBezierPath {
        if let importWalletView = importWalletView {
            let path = UIBezierPath(roundedRect: importWalletView.bounds, cornerRadius: 20)
            return path
        } else {
            return UIBezierPath()
        }
    }
}

extension TokensViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.hasContent
    }
}

extension TokensViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)
        delegate?.didSelect(token: token, in: self)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return viewModel.canDelete(for: indexPath.row, section: indexPath.section)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            delegate?.didDelete(token: viewModel.item(for: indexPath.row, section: indexPath.section), in: self)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)

        //TODO extract getting type of token/config from TokensDatastore class side and instance side
        let type: TokenType = {
            if token.isStormBird {
                return .stormBird
            }
            return TokensDataStore.etherToken(for: dataStore.config) == token ? .ether : .token
        }()

        switch type {
        case .ether:
            let cellViewModel = EthTokenViewCellViewModel(
                    token: token,
                    ticker: viewModel.ticker(for: token),
                    currencyAmount: session.balanceCoordinator.viewModel.currencyAmount,
                    currencyAmountWithoutSymbol: session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
            )
            return cellViewModel.cellHeight
        case .token:
            let cellViewModel = TokenViewCellViewModel(
                    token: token,
                    ticker: viewModel.ticker(for: token)
            )
            return cellViewModel.cellHeight
        case .stormBird:
            let cellViewModel = TicketTokenViewCellViewModel(
                    config: dataStore.config,
                    token: token,
                    ticker: viewModel.ticker(for: token)
            )
            return cellViewModel.cellHeight
        case .stormBirdOrder:
            let cellViewModel = TicketTokenViewCellViewModel(
                config: dataStore.config,
                token: token,
                ticker: viewModel.ticker(for: token)
            )
            return cellViewModel.cellHeight
        }
    }
}

extension TokensViewController: TokensDataStoreDelegate {
    func didUpdate(result: Result<TokensViewModel, TokenError>) {
        switch result {
        case .success(let viewModel):
            self.viewModel = viewModel
            endLoading()
        case .failure(let error):
            endLoading(error: error)
        }
        reload()

        if refreshControl.isRefreshing {
            refreshControl.endRefreshing()
        }
    }
}

extension TokensViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let token = viewModel.item(for: indexPath.row, section: indexPath.section)

        //TODO extract getting type of token/config from TokensDatastore class side and instance side
        let type: TokenType = {
            if token.isStormBird {
                return .stormBird
            }
            return TokensDataStore.etherToken(for: dataStore.config) == token ? .ether : .token
        }()

        switch type {
        case .ether:
            let cell = tableView.dequeueReusableCell(withIdentifier: EthTokenViewCell.identifier, for: indexPath) as! EthTokenViewCell
            cell.configure(
                    viewModel: .init(
                            token: token,
                            ticker: viewModel.ticker(for: token),
                            currencyAmount: session.balanceCoordinator.viewModel.currencyAmount,
                            currencyAmountWithoutSymbol: session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
                    )
            )
            return cell
        case .token:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenViewCell.identifier, for: indexPath) as! TokenViewCell
            cell.configure(
                    viewModel: .init(
                            token: token,
                            ticker: viewModel.ticker(for: token)
                    )
            )
            return cell
        case .stormBird:
            let cell = tableView.dequeueReusableCell(withIdentifier: TicketTokenViewCell.identifier, for: indexPath) as! TicketTokenViewCell
            cell.configure(
                    viewModel: .init(
                            config: dataStore.config,
                            token: token,
                            ticker: viewModel.ticker(for: token)
                    )
            )
            return cell
        case .stormBirdOrder:
            let cell = tableView.dequeueReusableCell(withIdentifier: TicketTokenViewCell.identifier, for: indexPath) as! TicketTokenViewCell
            cell.configure(
                viewModel: .init(
                    config: dataStore.config,
                    token: token,
                    ticker: viewModel.ticker(for: token)
                )
            )
            return cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }
}

extension TokensViewController: WalletFilterViewDelegate {
    func didPressWalletFilter(filter: WalletFilter, in filterView: WalletFilterView) {
        viewModel.filter = filter
        reload()
    }
}

