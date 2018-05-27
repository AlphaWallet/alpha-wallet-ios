// Copyright SIX DAY LLC. All rights reserved.

import TrustKeystore
import UIKit

protocol AccountsViewControllerDelegate: class {
    func didSelectAccount(account: Wallet, in viewController: AccountsViewController)
    func didDeleteAccount(account: Wallet, in viewController: AccountsViewController)
    func didSelectInfoForAccount(account: Wallet, sender: UIView, in viewController: AccountsViewController)
}

class AccountsViewController: UIViewController {
    let headerHeight = CGFloat(70)
    weak var delegate: AccountsViewControllerDelegate?
    var allowsAccountDeletion: Bool = false
    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
    let tableView = UITableView(frame: .zero, style: .plain)
    var viewModel: AccountsViewModel {
        return AccountsViewModel(
            wallets: wallets
        )
    }
    var hasWallets: Bool {
        return !keystore.wallets.isEmpty
    }
    var wallets: [Wallet] = [] {
        didSet {
            tableView.reloadData()
            configure(viewModel: viewModel)
        }
    }
    private var balances: [Address: Balance?] = [:]
    private let keystore: Keystore
    private let balanceCoordinator: GetBalanceCoordinator

    init(
        keystore: Keystore,
        balanceCoordinator: GetBalanceCoordinator
    ) {
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
        wallets = keystore.wallets
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
        ) { result in
            switch result {
            case .success:
                self.delete(account: account)
            case .failure: break
            }
        }
    }
    func delete(account: Wallet) {
        navigationController?.displayLoading(text: R.string.localizable.deleting())
        keystore.delete(wallet: account) { [weak self] result in
            guard let `self` = self else { return }
            self.navigationController?.hideLoading()
            switch result {
            case .success:
                self.fetch()
                self.delegate?.didDeleteAccount(account: account, in: self)
            case .failure(let error):
                self.displayError(error: error)
            }
        }
    }
    private func refreshWalletBalances() {
       let addresses = wallets.flatMap { $0.address }
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
        let model = AccountViewModel(wallet: account, current: EtherKeystore.current, walletBalance: balance)
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
        return allowsAccountDeletion && (EtherKeystore.current != viewModel.wallets[indexPath.row] || viewModel.wallets.count == 1)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
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
        self.delegate?.didSelectInfoForAccount(account: account, sender: cell.infoButton, in: self)
    }
}
