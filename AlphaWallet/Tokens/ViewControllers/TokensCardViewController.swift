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
    private let tokenObject: TokenObject
    private var viewModel: TokensCardViewModel
    private let tokensStorage: TokensDataStore
    private let account: Wallet
    private let header = TokenCardsViewControllerHeader()
    private let roundedBackground = RoundedBackground()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let redeemButton = UIButton(type: .system)
    private let sellButton = UIButton(type: .system)
    private let transferButton = UIButton(type: .system)

    let config: Config
    var contract: String {
        return tokenObject.contract
    }
    weak var delegate: TokensCardViewControllerDelegate?

    var isReadOnly = false {
        didSet {
            configure()
        }
    }

    var canPeekToken: Bool {
        let tokenType = OpenSeaNonFungibleTokenHandling(token: tokenObject)
        switch tokenType {
        case .supportedByOpenSea:
            return true
        case .notSupportedByOpenSea:
            return false
        }
    }

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
        tableView.register(OpenSeaNonFungibleTokenCardTableViewCellWithoutCheckbox.self, forCellReuseIdentifier: OpenSeaNonFungibleTokenCardTableViewCellWithoutCheckbox.identifier)
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

        registerForPreviewing(with: self, sourceView: tableView)
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
        redeemButton.setTitleColor(viewModel.disabledButtonTitleColor, for: .disabled)
		redeemButton.backgroundColor = viewModel.buttonBackgroundColor
        redeemButton.titleLabel?.font = viewModel.buttonFont

        sellButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        sellButton.setTitleColor(viewModel.disabledButtonTitleColor, for: .disabled)
        sellButton.backgroundColor = viewModel.buttonBackgroundColor
        sellButton.titleLabel?.font = viewModel.buttonFont

        transferButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        transferButton.setTitleColor(viewModel.disabledButtonTitleColor, for: .disabled)
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
        [redeemButton, sellButton, transferButton].forEach { $0.isEnabled = !isReadOnly }

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
        //TODO reloading only the affect cells show expanded cell with wrong height the first time, so we reload all instead and scroll the cell to the top instead
//        tableview.reloadRows(at: indexPaths, with: .automatic)
        tableview.reloadData()
        if indexPaths.count == 2 {
            if let indexPath = indexPaths.first(where: { viewModel.item(for: $0).areDetailsVisible }) {
                tableview.scrollToRow(at: indexPath, at: .top, animated: false)
            }
        }
    }

    private func toggleDetailsVisibility(forIndexPath indexPath: IndexPath) {
        let changedIndexPaths = viewModel.toggleDetailsVisible(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }

    private func canPeek(at indexPath: IndexPath) -> Bool {
        guard canPeekToken else { return false }
        let tokenHolder = viewModel.item(for: indexPath)
        if let url = tokenHolder.values["imageUrl"] as? String, !url.isEmpty {
            return true
        } else {
            return false
        }
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
        let tokenType = OpenSeaNonFungibleTokenHandling(token: tokenObject)
        switch tokenType {
        case .supportedByOpenSea:
            let cell = tableView.dequeueReusableCell(withIdentifier: OpenSeaNonFungibleTokenCardTableViewCellWithoutCheckbox.identifier, for: indexPath) as! OpenSeaNonFungibleTokenCardTableViewCellWithoutCheckbox
            cell.delegate = self
            cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width))
            return cell
        case .notSupportedByOpenSea:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenCardTableViewCellWithoutCheckbox.identifier, for: indexPath) as! TokenCardTableViewCellWithoutCheckbox
            cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width))
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        toggleDetailsVisibility(forIndexPath: indexPath)
    }
}

extension TokensCardViewController: BaseOpenSeaNonFungibleTokenCardTableViewCellDelegate {
    func didTapURL(url: URL) {
        delegate?.didPressOpenWebPage(url, in: self)
    }
}

extension TokensCardViewController: UIViewControllerPreviewingDelegate {
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = tableView.indexPathForRow(at: location) else { return nil }
        guard canPeek(at: indexPath) else { return nil }
        guard let cell = tableView.cellForRow(at: indexPath) else { return nil }
        let tokenHolder = viewModel.item(for: indexPath)
        guard !tokenHolder.areDetailsVisible else { return nil }

        let viewController = PeekOpenSeaNonFungibleTokenViewController(forIndexPath: indexPath)
        viewController.configure(viewModel: .init(tokenHolder: tokenHolder, areDetailsVisible: true, width: tableView.frame.size.width, convertHtmlInDescription: false))

        let viewRectInTableView = view.convert(cell.frame, from: tableView)
        previewingContext.sourceRect = viewRectInTableView
        //Don't need to set `preferredContentSize`. In fact, if we set the height, it seems to be rendered wrongly
        return viewController
    }

    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        guard let viewController = viewControllerToCommit as? PeekOpenSeaNonFungibleTokenViewController else { return }
        toggleDetailsVisibility(forIndexPath: viewController.indexPath)
    }
}
