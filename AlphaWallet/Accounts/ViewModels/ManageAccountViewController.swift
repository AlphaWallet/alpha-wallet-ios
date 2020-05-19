// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol ManageAccountViewControllerDelegate: class {
    func controller(_ controller: ManageAccountViewController, didSelectOption option: ManageAccountOption)
}

class ManageAccountViewController: UIViewController {

    private let viewModel: ManageAccountViewModel
    private var etherKeystore = try? EtherKeystore()
    private let balanceCoordinator: GetNativeCryptoCurrencyBalanceCoordinator
    private let roundedBackground = RoundedBackground()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    weak var delegate: ManageAccountViewControllerDelegate?
    
    init(viewModel: ManageAccountViewModel, balanceCoordinator: GetNativeCryptoCurrencyBalanceCoordinator) {
        self.viewModel = viewModel
        self.balanceCoordinator = balanceCoordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = Colors.appWhite
        tableView.tableFooterView = UIView()
        tableView.register(ManagedAccountTableViewCell.self, forCellReuseIdentifier: ManagedAccountTableViewCell.identifier)
        tableView.register(AccountOptionViewCell.self, forCellReuseIdentifier: AccountOptionViewCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
        
        title = viewModel.navigationTitle
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshWalletBalances()
    }
    
    private func refreshWalletBalances() {
        balanceCoordinator.getBalance(for: viewModel.wallet.address, completion: { [weak self] (result) in
            self?.viewModel.balance = result.value
                
            self?.tableView.reloadData()
        })
    }
    
    private func getAccountViewModel() -> AccountViewModel {
        let model = AccountViewModel(wallet: viewModel.wallet, current: etherKeystore?.recentlyUsedWallet, walletBalance: viewModel.balance, server: balanceCoordinator.server, showSelectionIcon: false)
        return model
    }
}

extension ManageAccountViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.viewModel.numberOfSections()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.viewModel.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = ManageAccountSection(rawValue: indexPath.section) else { return UITableViewCell() }
        switch section {
        case .account:
            let cell = tableView.dequeueReusableCell(withIdentifier: ManagedAccountTableViewCell.identifier, for: indexPath) as! ManagedAccountTableViewCell
            var cellViewModel = getAccountViewModel()
            cell.configure(viewModel: cellViewModel)
            cell.account = cellViewModel.wallet
            
            let serverToResolveEns = RPCServer.main
            let address = cellViewModel.address
            ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: address) { result in
                guard let ensName = result.value else { return }
                //Cell might have been reused. Check
                guard let cellAddress = cell.viewModel?.address, cellAddress.sameContract(as: address) else { return }
                cellViewModel.ensName = ensName
                cell.configure(viewModel: cellViewModel)
            }

            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: AccountOptionViewCell.identifier, for: indexPath) as! AccountOptionViewCell
            cell.configure(viewModel: viewModel.optionViewModel(indexPath: indexPath))
            cell.delegate = self
            
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch ManageAccountSection(rawValue: section) {
        case .some(.account):
            return nil
        case .some(.options):
            let headerView = UIView()
            headerView.backgroundColor = GroupedTable.Color.background

            return headerView
        case .none:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch ManageAccountSection(rawValue: section) {
        case .some(.account):
            return 0.1
        case .some(.options):
            return 50
        case .none:
            return 0.1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.1
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
}

extension ManageAccountViewController: UITableViewDelegate {
    
}

extension ManageAccountViewController: AccountOptionViewCellDelegate {
    
    func cell(_ cell: AccountOptionViewCell, didSelectOption sender: UIButton) {
        guard let indexPath = cell.indexPath, let option = ManageAccountOption(rawValue: indexPath.row) else { return }
     
        delegate?.controller(self, didSelectOption: option)
    }
}
