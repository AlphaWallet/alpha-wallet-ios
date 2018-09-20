//
//  TokensCardViewController.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import UIKit
import Result
import TrustKeystore

protocol TokensCardViewControllerDelegate: class, CanOpenURL {
    func didPressRedeem(token: TokenObject, in viewController: TokensCardViewController)
    func didPressSell(for type: PaymentFlow, in viewController: TokensCardViewController)
    func didPressTransfer(for type: PaymentFlow, tokenHolders: [TokenHolder], in viewController: TokensCardViewController)
    func didCancel(in viewController: TokensCardViewController)
    func didPressViewRedemptionInfo(in viewController: TokensCardViewController)
    func didTapURL(url: URL, in viewController: TokensCardViewController)
}

class TokensCardViewController: UIViewController, TokenVerifiableStatusViewController {

    let config: Config
    var contract: String {
        return tokenObject.contract
    }
    var tokenObject: TokenObject
    var viewModel: TokensCardViewModel
    let tokensStorage: TokensDataStore
    let account: Wallet
    weak var delegate: TokensCardViewControllerDelegate?
    let header = TokenCardsViewControllerHeader()
    let roundedBackground = RoundedBackground()
    let tableView = UITableView(frame: .zero, style: .plain)

    let redeemButton = UIButton(type: .system)
    let sellButton = UIButton(type: .system)
    let transferButton = UIButton(type: .system)

    init(config: Config, tokenObject: TokenObject, account: Wallet, tokensStorage: TokensDataStore, viewModel: TokensCardViewModel) {
        self.config = config
        self.tokenObject = tokenObject
        self.account = account
        self.tokensStorage = tokensStorage
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        view.backgroundColor = Colors.appBackground
		
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.register(TokenCardTableViewCellWithoutCheckbox.self, forCellReuseIdentifier: TokenCardTableViewCellWithoutCheckbox.identifier)
        tableView.register(TokenListFormatTableViewCellWithoutCheckbox.self, forCellReuseIdentifier: TokenListFormatTableViewCellWithoutCheckbox.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.tableHeaderView = header
        tableView.rowHeight = UITableViewAutomaticDimension
        roundedBackground.addSubview(tableView)

        redeemButton.setTitle(R.string.localizable.aWalletTokenRedeemButtonTitle(), for: .normal)
        redeemButton.addTarget(self, action: #selector(redeem), for: .touchUpInside)

        sellButton.setTitle(R.string.localizable.aWalletTokenSellButtonTitle(), for: .normal)
        sellButton.addTarget(self, action: #selector(sell), for: .touchUpInside)

        transferButton.setTitle(R.string.localizable.aWalletTokenTransferButtonTitle(), for: .normal)
        transferButton.addTarget(self, action: #selector(transfer), for: .touchUpInside)

        let buttonsStackView = [redeemButton, sellButton, transferButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        let separator0 = UIView()
        separator0.translatesAutoresizingMaskIntoConstraints = false
        separator0.backgroundColor = Colors.appLightButtonSeparator
        footerBar.addSubview(separator0)

        let separator1 = UIView()
        separator1.translatesAutoresizingMaskIntoConstraints = false
        separator1.backgroundColor = separator0.backgroundColor
        footerBar.addSubview(separator1)

		let separatorThickness = CGFloat(1)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            separator0.leadingAnchor.constraint(equalTo: redeemButton.trailingAnchor, constant: -separatorThickness / 2),
            separator0.trailingAnchor.constraint(equalTo: sellButton.leadingAnchor, constant: separatorThickness / 2),
			separator0.topAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: 8),
            separator0.bottomAnchor.constraint(equalTo: buttonsStackView.bottomAnchor, constant: -8),

            separator1.leadingAnchor.constraint(equalTo: sellButton.trailingAnchor, constant: -0.5),
            separator1.trailingAnchor.constraint(equalTo: transferButton.leadingAnchor, constant: 0.5),
            separator1.topAnchor.constraint(equalTo: separator0.topAnchor),
            separator1.bottomAnchor.constraint(equalTo: separator0.bottomAnchor),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel newViewModel: TokensCardViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        tableView.dataSource = self
        updateNavigationRightBarButtons(isVerified: isContractVerified)

        header.configure(viewModel: .init(tokenObject: tokenObject))
        tableView.tableHeaderView = header

        redeemButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		redeemButton.backgroundColor = viewModel.buttonBackgroundColor
        redeemButton.titleLabel?.font = viewModel.buttonFont

        sellButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        sellButton.backgroundColor = viewModel.buttonBackgroundColor
        sellButton.titleLabel?.font = viewModel.buttonFont

        transferButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        transferButton.backgroundColor = viewModel.buttonBackgroundColor
        transferButton.titleLabel?.font = viewModel.buttonFont

        switch tokenObject.type {
        case .ether:
            break
        case .erc20:
            break
        case .erc875:
            redeemButton.isHidden = false
            sellButton.isHidden = false
        case .erc721:
            redeemButton.isHidden = true
            sellButton.isHidden = true
        }

        tableView.reloadData()
    }

    override
    func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(didTapCancelButton))
    }

    @IBAction
    func didTapCancelButton(_ sender: UIBarButtonItem) {
        delegate?.didCancel(in: self)
    }

    @objc func redeem() {
        delegate?.didPressRedeem(token: viewModel.token,
                                 in: self)
    }

    @objc func sell() {
        delegate?.didPressSell(for: .send(type: .ERC875Token(viewModel.token)), in: self)
    }

    @objc func transfer() {
        let transferType = TransferType(token: viewModel.token)
        delegate?.didPressTransfer(for: .send(type: transferType),
                                   tokenHolders: viewModel.tokenHolders,
                                   in: self)
    }

    func showInfo() {
		delegate?.didPressViewRedemptionInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: tokenObject.contract, in: self)
    }

    private func animateRowHeightChanges(for indexPaths: [IndexPath], in tableview: UITableView) {
        tableView.reloadData()
    }
}

extension TokensCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tokenHolder = viewModel.item(for: indexPath)
        let tokenType = CryptoKittyHandling(contract: tokenHolder.contractAddress)
        switch tokenType {
        case .cryptoKitty:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenListFormatTableViewCellWithoutCheckbox.identifier, for: indexPath) as! TokenListFormatTableViewCellWithoutCheckbox
            cell.delegate = self
            cell.configure(viewModel: .init(tokenHolder: tokenHolder))
            return cell
        case .otherNonFungibleToken:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenCardTableViewCellWithoutCheckbox.identifier, for: indexPath) as! TokenCardTableViewCellWithoutCheckbox
            cell.configure(viewModel: .init(tokenHolder: tokenHolder))
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let changedIndexPaths = viewModel.toggleDetailsVisible(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }
}

extension TokensCardViewController: BaseTokenListFormatTableViewCellDelegate {
    func didTapURL(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}
