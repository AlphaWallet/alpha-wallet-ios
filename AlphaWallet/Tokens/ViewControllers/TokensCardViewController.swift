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

protocol TokensCardViewControllerDelegate: class, CanOpenURL {
    func didPressRedeem(token: TokenObject, tokenHolder: TokenHolder, in viewController: TokensCardViewController)
    func didPressSell(tokenHolder: TokenHolder, for paymentFlow: PaymentFlow, in viewController: TokensCardViewController)
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, for type: PaymentFlow, tokenHolders: [TokenHolder], in viewController: TokensCardViewController)
    func didCancel(in viewController: TokensCardViewController)
    func didPressViewRedemptionInfo(in viewController: TokensCardViewController)
    func didTapURL(url: URL, in viewController: TokensCardViewController)
    func didTapTokenInstanceIconified(tokenHolder: TokenHolder, in viewController: TokensCardViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokensCardViewController)
}

//TODO rename to be appropriate for TokenScript
class TokensCardViewController: UIViewController, TokenVerifiableStatusViewController {
    static let anArbitaryRowHeightSoAutoSizingCellsWorkIniOS10 = CGFloat(100)

    private let tokenObject: TokenObject
    private var viewModel: TokensCardViewModel
    private let tokensStorage: TokensDataStore
    private let account: Wallet
    private let header = TokenCardsViewControllerHeader()
    private let roundedBackground = RoundedBackground()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let buttonsBar = ButtonsBar(numberOfButtons: 3)
    private var isMultipleSelectionMode = false {
        didSet {
            if isMultipleSelectionMode {
                tableView.reloadData()
            } else {
                //We don't handle setting it to false
            }
        }
    }
    private var selectedTokenHolder: TokenHolder? {
        let selectedTokenHolders = viewModel.tokenHolders.filter { $0.isSelected }
        return selectedTokenHolders.first
    }

    var server: RPCServer {
        return tokenObject.server
    }
    var contract: AlphaWallet.Address {
        return tokenObject.contractAddress
    }
    let assetDefinitionStore: AssetDefinitionStore
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

    init(tokenObject: TokenObject, account: Wallet, tokensStorage: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, viewModel: TokensCardViewModel) {
        self.tokenObject = tokenObject
        self.account = account
        self.tokensStorage = tokensStorage
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore
        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        view.backgroundColor = Colors.appBackground
		
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        header.delegate = self

        tableView.register(TokenCardTableViewCellWithCheckbox.self, forCellReuseIdentifier: TokenCardTableViewCellWithCheckbox.identifier)
        tableView.register(OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox.self, forCellReuseIdentifier: OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.tableHeaderView = header
        tableView.estimatedRowHeight = TokensCardViewController.anArbitaryRowHeightSoAutoSizingCellsWorkIniOS10
        roundedBackground.addSubview(tableView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
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
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        header.configure(viewModel: .init(tokenObject: tokenObject, server: tokenObject.server, assetDefinitionStore: assetDefinitionStore))
        tableView.tableHeaderView = header

        if selectedTokenHolder != nil {
            let actions = viewModel.actions
            buttonsBar.numberOfButtons = actions.count
            buttonsBar.configure()
            for (action, button) in zip(actions, buttonsBar.buttons) {
                button.setTitle(action.name, for: .normal)
                button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
                switch account.type {
                case .real:
                    button.isEnabled = true
                case .watch:
                    button.isEnabled = false
                }
            }
        } else {
            buttonsBar.numberOfButtons = 0
        }

        tableView.reloadData()
    }

    override
    func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(didTapCancelButton))
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

    @IBAction
    func didTapCancelButton(_ sender: UIBarButtonItem) {
        delegate?.didCancel(in: self)
    }

    func redeem() {
        guard let selectedTokenHolder = selectedTokenHolder else { return }
        delegate?.didPressRedeem(token: viewModel.token, tokenHolder: selectedTokenHolder, in: self)
    }

    func sell() {
        guard let selectedTokenHolder = selectedTokenHolder else { return }
        delegate?.didPressSell(tokenHolder: selectedTokenHolder, for: .send(type: .ERC875Token(viewModel.token)), in: self)
    }

    func transfer() {
        guard let selectedTokenHolder = selectedTokenHolder else { return }
        let transferType = TransferType(token: viewModel.token)
        delegate?.didPressTransfer(token: viewModel.token, tokenHolder: selectedTokenHolder, for: .send(type: transferType), tokenHolders: viewModel.tokenHolders, in: self)
    }

    //TODO multi-selection. Only supports selecting one tokenHolder for now
    @objc private func actionButtonTapped(sender: UIButton) {
        guard let tokenHolder = selectedTokenHolder else { return }
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) {
            if button == sender {
                switch action.type {
                case .erc20Send, .erc20Receive:
                    break
                case .erc875Redeem:
                    redeem()
                case .erc875Sell:
                    sell()
                case .nonFungibleTransfer:
                    transfer()
                case .tokenScript:
                    delegate?.didTap(action: action, tokenHolder: tokenHolder, viewController: self)
                }
                break
            }
        }
    }

    private func animateRowHeightChanges(for indexPaths: [IndexPath], in tableview: UITableView) {
        guard !indexPaths.isEmpty else { return }
        //TODO reloading only the affect cells show expanded cell with wrong height the first time, so we reload all instead and scroll the cell to the top instead
//        tableview.reloadRows(at: indexPaths, with: .automatic)
        tableview.reloadData()
        let anyIndexPath = indexPaths[0]
        let _ = viewModel.item(for: anyIndexPath).tokens[0]
        //We only auto scroll to reveal for OpenSea-supported tokens which are usually taller and have a picture. Because
        //    (A) other tokens like ERC875 tickets are usually too short and all text, making it difficult for user to capture where it has scrolled to
        //    (B) OpenSea-supported tokens are tall, so after expanding, chances are user need to scroll quite a lot if we don't auto-scroll
        switch OpenSeaNonFungibleTokenHandling(token: viewModel.token) {
        case .supportedByOpenSea:
            if let indexPath = indexPaths.first(where: { viewModel.item(for: $0).areDetailsVisible }) {
                tableview.scrollToRow(at: indexPath, at: .top, animated: false)
            }
        case .notSupportedByOpenSea:
            break
        }
    }

    private func toggleDetailsVisibility(forIndexPath indexPath: IndexPath) {
        let changedIndexPaths = viewModel.toggleDetailsVisible(for: indexPath)
        animateRowHeightChanges(for: changedIndexPaths, in: tableView)
    }

    private func canPeek(at indexPath: IndexPath) -> Bool {
        guard canPeekToken else { return false }
        let tokenHolder = viewModel.item(for: indexPath)
        if let url = tokenHolder.values["imageUrl"]?.stringValue, !url.isEmpty {
            return true
        } else {
            return false
        }
    }

    @objc private func longPressedTokenInstanceIconified(sender: UILongPressGestureRecognizer) {
       switch sender.state {
       case .began:
           isMultipleSelectionMode = true
           guard let indexPaths = tableView.indexPathsForVisibleRows else { return }
           for each in indexPaths {
               guard let cell = tableView.cellForRow(at: each) else { continue }
               if let hasGestureRecognizer = cell.gestureRecognizers?.contains(sender), hasGestureRecognizer {
                   let _ = viewModel.toggleSelection(for: each)
                   configure()
                   break
               }
           }
       case .possible, .changed, .ended, .cancelled, .failed:
           break
       }
    }
}
extension TokensCardViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewRedemptionInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: tokenObject.contractAddress, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension TokensCardViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems(for: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tokenHolder = viewModel.item(for: indexPath)
        let tokenType = OpenSeaNonFungibleTokenHandling(token: tokenObject)
        switch tokenType {
        case .supportedByOpenSea:
            let cell = tableView.dequeueReusableCell(withIdentifier: OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox.identifier, for: indexPath) as! OpenSeaNonFungibleTokenCardTableViewCellWithCheckbox
            cell.delegate = self
            cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width, tokenView: .viewIconified))
            cell.isCheckboxVisible  = isMultipleSelectionMode
            let hasAddedGestureRecognizer = cell.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer} ?? false
            if !hasAddedGestureRecognizer {
                cell.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPressedTokenInstanceIconified)))
            }
            return cell
        case .notSupportedByOpenSea:
            let cell = tableView.dequeueReusableCell(withIdentifier: TokenCardTableViewCellWithCheckbox.identifier, for: indexPath) as! TokenCardTableViewCellWithCheckbox
            cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width, tokenView: .viewIconified), assetDefinitionStore: assetDefinitionStore)
            cell.isCheckboxVisible  = isMultipleSelectionMode
            let hasAddedGestureRecognizer = cell.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer} ?? false
            if !hasAddedGestureRecognizer {
                cell.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPressedTokenInstanceIconified)))
            }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isMultipleSelectionMode {
            let _ = viewModel.toggleSelection(for: indexPath)
            //TODO maybe still needed for ERC721
//            animateRowHeightChanges(for: changedIndexPaths, in: tableView)
            configure()
        } else {
            let tokenHolder = viewModel.item(for: indexPath)
            delegate?.didTapTokenInstanceIconified(tokenHolder: tokenHolder, in: self)
        }
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

extension TokensCardViewController: TokenCardsViewControllerHeaderDelegate {
    func didPressViewContractWebPage(inHeaderView: TokenCardsViewControllerHeader) {
        showContractWebPage()
    }
}
