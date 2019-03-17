// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenViewControllerDelegate: class, CanOpenURL {
    func didTapSend(forTransferType transferType: TransferType, inViewController viewController: TokenViewController)
    func didTapReceive(forTransferType transferType: TransferType, inViewController viewController: TokenViewController)
    func didTap(transaction: Transaction, inViewController viewController: TokenViewController)
}

class TokenViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private let header = TokenViewControllerHeaderView()
    lazy private var headerViewModel = SendHeaderViewViewModel(config: session.config)
    private var viewModel: TokenViewControllerViewModel?
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    private let transferType: TransferType
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let buttonsBar = ButtonsBar(numberOfButtons: 2)

    weak var delegate: TokenViewControllerDelegate?

    init(session: WalletSession, tokensDataStore: TokensDataStore, transferType: TransferType) {
        self.session = session
        self.tokensDataStore = tokensDataStore
        self.transferType = transferType

        super.init(nibName: nil, bundle: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        header.delegate = self

        tableView.register(TokenViewControllerTransactionCell.self, forCellReuseIdentifier: TokenViewControllerTransactionCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = header
        tableView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(tableView)

        roundedBackground.addSubview(buttonsBar)

        configureBalanceViewModel()

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),

            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
            buttonsBar.bottomAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.marginAtBottomScreen),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TokenViewControllerViewModel) {
        self.viewModel = viewModel
        view.backgroundColor = viewModel.backgroundColor

        headerViewModel.showAlternativeAmount = viewModel.showAlternativeAmount

        switch transferType {
        case .nativeCryptocurrency:
            header.verificationStatus = .verified(session.account.address.eip55String)
        case .ERC20Token(let token), .ERC875TokenOrder(let token), .ERC875Token(let token), .ERC721Token(let token):
            header.verificationStatus = .unverified(token.contract)
        case .dapp:
            header.verificationStatus = .unverified(session.account.address.eip55String)
        }
        header.sendHeaderView.configure(viewModel: headerViewModel)
        header.frame.size.height = 220
        tableView.tableHeaderView = header

        buttonsBar.configure()

        let sendButton = buttonsBar.buttons[0]
        sendButton.setTitle(viewModel.sendButtonTitle, for: .normal)
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        let receiveButton = buttonsBar.buttons[1]
        receiveButton.setTitle(viewModel.receiveButtonTitle, for: .normal)
        receiveButton.addTarget(self, action: #selector(receive), for: .touchUpInside)

        tableView.reloadData()
    }

    private func configureBalanceViewModel() {
        switch transferType {
        case .nativeCryptocurrency:
            session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self, let viewModel = viewModel else { return }
                let amount = viewModel.amountShort
                celf.headerViewModel.title = "\(amount) \(celf.session.config.server.name) (\(viewModel.symbol))"
                let etherToken = TokensDataStore.etherToken(for: celf.session.config)
                let ticker = celf.tokensDataStore.coinTicker(for: etherToken)
                celf.headerViewModel.ticker = ticker
                celf.headerViewModel.currencyAmount = celf.session.balanceCoordinator.viewModel.currencyAmount
                celf.headerViewModel.currencyAmountWithoutSymbol = celf.session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
                if let viewModel = celf.viewModel {
                    celf.configure(viewModel: viewModel)
                }
            }
            session.refresh(.ethBalance)
        case .ERC20Token(let token):
            let viewModel = BalanceTokenViewModel(token: token)
            let amount = viewModel.amountShort
            headerViewModel.title = "\(amount) \(viewModel.name) (\(viewModel.symbol))"
            let etherToken = TokensDataStore.etherToken(for: session.config)
            let ticker = tokensDataStore.coinTicker(for: etherToken)
            headerViewModel.ticker = ticker
            headerViewModel.currencyAmount = session.balanceCoordinator.viewModel.currencyAmount
            headerViewModel.currencyAmountWithoutSymbol = session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
            if let viewModel = self.viewModel {
                configure(viewModel: viewModel)
            }
        case .ERC875Token(_), .ERC875TokenOrder(_), .ERC721Token(_), .dapp(_, _):
            break
        }
    }

    @objc private func send() {
        delegate?.didTapSend(forTransferType: transferType, inViewController: self)
    }

    @objc private func receive() {
        delegate?.didTapReceive(forTransferType: transferType, inViewController: self)
    }
}

extension TokenViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TokenViewControllerTransactionCell.identifier, for: indexPath) as! TokenViewControllerTransactionCell
        if let transaction = viewModel?.recentTransactions[indexPath.row] {
            let viewModel = TokenViewControllerTransactionCellViewModel(
                    transaction: transaction,
                    config: session.config,
                    chainState: session.chainState,
                    currentWallet: session.account
            )
            cell.configure(viewModel: viewModel)
        } else {
            cell.configureEmpty()
        }
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.recentTransactions.count ?? 0
    }
}

extension TokenViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let transaction = viewModel?.recentTransactions[indexPath.row] else { return }
        delegate?.didTap(transaction: transaction, inViewController: self)
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 94
    }
}

extension TokenViewController: TokenViewControllerHeaderViewDelegate {
    func didPressViewContractWebPage(forContract contract: String, inHeaderView: TokenViewControllerHeaderView) {
        delegate?.didPressViewContractWebPage(forContract: contract, in: self)
    }
}
