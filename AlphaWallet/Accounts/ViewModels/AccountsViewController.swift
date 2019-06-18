// Copyright SIX DAY LLC. All rights reserved.

import UIKit

protocol AccountsViewControllerDelegate: class {
    func didSelectAccount(account: Wallet, in viewController: AccountsViewController)
    func didDeleteAccount(account: Wallet, in viewController: AccountsViewController)
    func didSelectInfoForAccount(account: Wallet, sender: UIView, in viewController: AccountsViewController)
}

class AccountsViewController: UIViewController {
    private let headerHeight = CGFloat(70)
    private let roundedBackground = RoundedBackground()
    private let header = TokensCardViewControllerTitleHeader()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var viewModel: AccountsViewModel {
        return AccountsViewModel(
                wallets: wallets
        )
    }
    private var wallets: [Wallet] = [] {
        didSet {
            tableView.reloadData()
            configure(viewModel: viewModel)
        }
    }
    private var balances: [AlphaWallet.Address: Balance?] = [:]
    private let keystore: Keystore
    private let balanceCoordinator: GetBalanceCoordinator
    private var etherKeystore = try? EtherKeystore()

    weak var delegate: AccountsViewControllerDelegate?
    var allowsAccountDeletion: Bool = false
    var hasWallets: Bool {
        return !keystore.wallets.isEmpty
    }

    init(keystore: Keystore, balanceCoordinator: GetBalanceCoordinator) {
        self.keystore = keystore
        self.balanceCoordinator = balanceCoordinator
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.rowHeight = 80
        tableView.tableHeaderView = header
        tableView.register(AccountViewCell.self, forCellReuseIdentifier: AccountViewCell.identifier)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: headerHeight),

            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        fetch()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetch()
        refreshWalletBalances()
    }
    func fetch() {
        wallets = keystore.wallets.sorted { $0.address.eip55String < $1.address.eip55String }
    }
    func configure(viewModel: AccountsViewModel) {
        tableView.dataSource = self
        header.configure(title: viewModel.title)
        header.frame.size.height = headerHeight
        tableView.tableHeaderView = header
    }
    func account(for indexPath: IndexPath) -> Wallet {
        return viewModel.wallets[indexPath.row]
    }
    func confirmDelete(account: Wallet) {
        confirm(
            title: R.string.localizable.accountsConfirmDeleteTitle(),
            message: R.string.localizable.accountsConfirmDeleteMessage(),
            okTitle: R.string.localizable.accountsConfirmDeleteOkTitle(),
            okStyle: .destructive
        ) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success:
                strongSelf.delete(account: account)
            case .failure: break
            }
        }
    }
    func delete(account: Wallet) {
        navigationController?.displayLoading(text: R.string.localizable.deleting())
        keystore.delete(wallet: account) { [weak self] result in
            guard let strongSelf = self else { return }
            strongSelf.navigationController?.hideLoading()
            switch result {
            case .success:
                strongSelf.fetch()
                strongSelf.delegate?.didDeleteAccount(account: account, in: strongSelf)
            case .failure(let error):
                strongSelf.displayError(error: error)
            }
        }
    }
    private func refreshWalletBalances() {
        let addresses = wallets.compactMap { $0.address }
       var counter = 0
       for address in addresses {
            balanceCoordinator.getEthBalance(for: address, completion: { [weak self] (result) in
                self?.balances[address] = result.value
                counter += 1
                if counter == addresses.count {
                    self?.tableView.reloadData()
                }
            })
        }
    }
    private func getAccountViewModels(for path: IndexPath) -> AccountViewModel {
        let account = self.account(for: path)
        let balance = self.balances[account.address].flatMap { $0 }
        let model = AccountViewModel(wallet: account, current: etherKeystore?.recentlyUsedWallet, walletBalance: balance, server: balanceCoordinator.server)
        return model
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AccountsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.wallets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AccountViewCell.identifier, for: indexPath) as! AccountViewCell
        let cellViewModel = getAccountViewModels(for: indexPath)
        cell.configure(viewModel: cellViewModel)
        cell.account = cellViewModel.wallet
        cell.delegate = self
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return allowsAccountDeletion && (etherKeystore?.recentlyUsedWallet != viewModel.wallets[indexPath.row])
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let account = self.account(for: indexPath)
            confirmDelete(account: account)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let account = self.account(for: indexPath)
        delegate?.didSelectAccount(account: account, in: self)
    }
}

extension AccountsViewController: AccountViewCellDelegate {
    func accountViewCell(_ cell: AccountViewCell, didTapInfoViewForAccount account: Wallet) {
        delegate?.didSelectInfoForAccount(account: account, sender: cell.infoButton, in: self)
    }
}
