// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

protocol TokenViewControllerDelegate: class, CanOpenURL {
    func didTapSend(forTransferType transferType: TransferType, inViewController viewController: TokenViewController)
    func didTapReceive(forTransferType transferType: TransferType, inViewController viewController: TokenViewController)
    func didTap(transaction: Transaction, inViewController viewController: TokenViewController)
    func didTap(action: TokenInstanceAction, transferType: TransferType, viewController: TokenViewController)
}

class TokenViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    lazy private var header = {
        return TokenViewControllerHeaderView(contract: transferType.contract)
    }()
    lazy private var headerViewModel = SendHeaderViewViewModel(server: session.server)
    private var viewModel: TokenViewControllerViewModel?
    private var tokenHolder: TokenHolder?
    private let session: WalletSession
    private let tokensDataStore: TokensDataStore
    private let assetDefinitionStore: AssetDefinitionStore
    private let transferType: TransferType
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 2))

    weak var delegate: TokenViewControllerDelegate?

    init(session: WalletSession, tokensDataStore: TokensDataStore, assetDefinition: AssetDefinitionStore, transferType: TransferType) {
        self.session = session
        self.tokensDataStore = tokensDataStore
        self.assetDefinitionStore = assetDefinition
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

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        configureBalanceViewModel()

        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),

            tableView.anchorsConstraint(to: roundedBackground),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            roundedBackground.createConstraintsWithContainer(view: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let buttonsBarHolder = buttonsBar.superview else {
            tableView.contentInset = .zero
            return
        }
        //TODO We are basically calculating the bottom safe area here. Don't rely on the internals of how buttonsBar and it's parent are laid out
        if buttonsBar.isEmpty {
            tableView.contentInset = .init(top: 0, left: 0, bottom: buttonsBarHolder.frame.size.height - buttonsBar.frame.size.height, right: 0)
        } else {
            tableView.contentInset = .init(top: 0, left: 0, bottom: tableView.frame.size.height - buttonsBarHolder.frame.origin.y, right: 0)
        }
    }

    func configure(viewModel: TokenViewControllerViewModel) {
        self.viewModel = viewModel
        view.backgroundColor = viewModel.backgroundColor

        headerViewModel.showAlternativeAmount = viewModel.showAlternativeAmount

        let xmlHandler = XMLHandler(contract: transferType.contract, assetDefinitionStore: assetDefinitionStore)
        let tokenScriptStatusPromise = xmlHandler.tokenScriptStatus
        if tokenScriptStatusPromise.isPending {
            tokenScriptStatusPromise.done { _ in
                self.configure(viewModel: viewModel)
            }.cauterize()
        }
        if let server = xmlHandler.server, server == session.server {
            header.tokenScriptFileStatus = tokenScriptStatusPromise.value
        } else {
            header.tokenScriptFileStatus = .type0NoTokenScript
        }
        header.sendHeaderView.configure(viewModel: headerViewModel)
        header.frame.size.height = header.systemLayoutSizeFitting(.zero).height

        tableView.tableHeaderView = header

        let actions = viewModel.actions
        buttonsBar.configure(.combined(buttons: viewModel.actions.count))
        buttonsBar.viewController = self
        
        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
            switch session.account.type {
            case .real:
                if let tokenHolder = generateTokenHolder(), let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address, fungibleBalance: viewModel.fungibleBalance) {
                    if selection.denial == nil {
                        button.displayButton = false
                    }
                }  
            case .watch:
                button.isEnabled = false
            }
        }

        tableView.reloadData()
    }

    private func configureBalanceViewModel() {
        switch transferType {
        case .nativeCryptocurrency:
            session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self, let viewModel = viewModel else { return }
                let amount = viewModel.amountShort
                celf.headerViewModel.title = "\(amount) \(celf.session.server.name) (\(viewModel.symbol))"
                let etherToken = TokensDataStore.etherToken(forServer: celf.session.server)
                let ticker = celf.tokensDataStore.coinTicker(for: etherToken)
                celf.headerViewModel.ticker = ticker
                celf.headerViewModel.currencyAmount = celf.session.balanceCoordinator.viewModel.currencyAmount
                celf.headerViewModel.currencyAmountWithoutSymbol = celf.session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
                if let viewModel = celf.viewModel {
                    celf.configure(viewModel: viewModel)
                }
            }
            session.refresh(.ethBalance)
        case .ERC20Token(let token, _, _):
            let amount = EtherNumberFormatter.short.string(from: token.valueBigInt, decimals: token.decimals)
            //Note that if we want to display the token name directly from token.name, we have to be careful that DAI token's name has trailing \0
            headerViewModel.title = "\(amount) \(token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore))"
            let etherToken = TokensDataStore.etherToken(forServer: session.server)
            let ticker = tokensDataStore.coinTicker(for: etherToken)
            headerViewModel.ticker = ticker
            headerViewModel.currencyAmount = session.balanceCoordinator.viewModel.currencyAmount
            headerViewModel.currencyAmountWithoutSymbol = session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
            if let viewModel = self.viewModel {
                configure(viewModel: viewModel)
            }
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
            break
        }
    }

    @objc private func send() {
        delegate?.didTapSend(forTransferType: transferType, inViewController: self)
    }

    @objc private func receive() {
        delegate?.didTapReceive(forTransferType: transferType, inViewController: self)
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        guard let viewModel = viewModel else { return }
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .erc20Send:
                send()
            case .erc20Receive:
                receive()
            case .nftRedeem, .nftSell, .nonFungibleTransfer:
                break
            case .tokenScript:
                if let tokenHolder = generateTokenHolder(), let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address, fungibleBalance: viewModel.fungibleBalance) {
                    if let denialMessage = selection.denial {
                        let alertController = UIAlertController.alert(
                                title: nil,
                                message: denialMessage,
                                alertButtonTitles: [R.string.localizable.oK()],
                                alertButtonStyles: [.default],
                                viewController: self,
                                completion: nil
                        )
                    } else {
                        //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                    }
                } else {
                    delegate?.didTap(action: action, transferType: transferType, viewController: self)
                }
            }
            break
        }
    }

    private func generateTokenHolder() -> TokenHolder? {
        //TODO is it correct to generate the TokenHolder instance once and never replace it? If not, we have to be very careful with subscriptions. Not re-subscribing in an infinite loop
        guard tokenHolder == nil else { return tokenHolder }

        //TODO id 1 for fungibles. Might come back to bite us?
        let hardcodedTokenIdForFungibles = BigUInt(1)
        guard let tokenObject = viewModel?.token else {return nil }
        let xmlHandler = XMLHandler(contract: tokenObject.contractAddress, assetDefinitionStore: assetDefinitionStore)
        //TODO Event support, if/when designed for fungibles
        let values = xmlHandler.resolveAttributesBypassingCache(withTokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), server: self.session.server, account: self.session.account)
        let subscribablesForAttributeValues = values.values
        let allResolved = subscribablesForAttributeValues.allSatisfy { $0.subscribableValue?.value != nil }
        if allResolved {
            //no-op
        } else {
            for each in subscribablesForAttributeValues {
                guard let subscribable = each.subscribableValue else { continue }
                let subscriptionKey = subscribable.subscribe { [weak self] value in
                    guard let strongSelf = self else { return }
                    guard let viewModel = strongSelf.viewModel else { return }
                    strongSelf.configure(viewModel: viewModel)
                }
            }
        }


        let token = Token(tokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), tokenType: tokenObject.type, index: 0, name: tokenObject.name, symbol: tokenObject.symbol, status: .available, values: values)
        tokenHolder = TokenHolder(tokens: [token], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)
        return tokenHolder
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
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, inHeaderView: TokenViewControllerHeaderView) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: session.server, in: self)
    }

    func didPressViewWebPage(url: URL, inHeaderView: TokenViewControllerHeaderView) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}
