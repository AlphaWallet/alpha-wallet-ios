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
    private var headerViewModel = SendHeaderViewViewModel()
    private var viewModel: TokenViewControllerViewModel?
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    private let transferType: TransferType
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let sendButton = UIButton(type: .system)
    private let receiveButton = UIButton(type: .system)

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

        let buttonsStackView = [.spacerWidth(20), sendButton, .spacerWidth(7), receiveButton, .spacerWidth(20)].asStackView(axis: .horizontal)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(buttonsStackView)

        configureBalanceViewModel()

        let buttonsHeight = Metrics.greenButtonHeight
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),

            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor),

            sendButton.widthAnchor.constraint(equalTo: receiveButton.widthAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),
            //Some gap so it doesn't stick to the bottom of devices without a bottom safe area
            buttonsStackView.bottomAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -7),
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
        case .ether:
            header.verificationStatus = .verified(session.account.address.eip55String)
        case .ERC20Token, .ERC875TokenOrder, .ERC875Token, .ERC721Token, .dapp:
            header.verificationStatus = .unverified
        }
        header.sendHeaderView.configure(viewModel: headerViewModel)
        header.frame.size.height = 220
        tableView.tableHeaderView = header

        sendButton.setTitle(viewModel.sendButtonTitle, for: .normal)
        sendButton.addTarget(self, action: #selector(send), for: .touchUpInside)
        sendButton.setBackgroundColor(viewModel.sendReceiveButtonBackgroundColor, forState: .normal)
        sendButton.setTitleColor(viewModel.sendReceiveButtonTitleColor, for: .normal)
        sendButton.cornerRadius = viewModel.sendReceiveButtonCornerRadius

        receiveButton.setTitle(viewModel.receiveButtonTitle, for: .normal)
        receiveButton.addTarget(self, action: #selector(receive), for: .touchUpInside)
        receiveButton.setBackgroundColor(viewModel.sendReceiveButtonBackgroundColor, forState: .normal)
        receiveButton.setTitleColor(viewModel.sendReceiveButtonTitleColor, for: .normal)
        receiveButton.cornerRadius = viewModel.sendReceiveButtonCornerRadius

        tableView.reloadData()
    }

    private func configureBalanceViewModel() {
        switch transferType {
        case .ether, .xDai:
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
            headerViewModel.title = "\(amount) \(viewModel.symbol)"
            let etherToken = TokensDataStore.etherToken(for: session.config)
            let ticker = tokensDataStore.coinTicker(for: etherToken)
            headerViewModel.ticker = ticker
            headerViewModel.currencyAmount = session.balanceCoordinator.viewModel.currencyAmount
            headerViewModel.currencyAmountWithoutSymbol = session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
            if let viewModel = self.viewModel {
                configure(viewModel: viewModel)
            }
        default:
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
