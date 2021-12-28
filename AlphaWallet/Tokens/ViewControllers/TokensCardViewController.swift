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
    func didPressTransfer(token: TokenObject, tokenHolder: TokenHolder, for type: PaymentFlow, in viewController: TokensCardViewController)
    func didCancel(in viewController: TokensCardViewController)
    func didPressViewRedemptionInfo(in viewController: TokensCardViewController)
    func didTapURL(url: URL, in viewController: TokensCardViewController)
    func didTapTokenInstanceIconified(tokenHolder: TokenHolder, in viewController: TokensCardViewController)
    func didTap(action: TokenInstanceAction, tokenHolder: TokenHolder, viewController: TokensCardViewController)
}

//TODO rename to be appropriate for TokenScript
class TokensCardViewController: UIViewController, TokenVerifiableStatusViewController {
    static let anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10 = CGFloat(100)
    private var sizingCell: TokenCardTableViewCellWithCheckbox?

    private let analyticsCoordinator: AnalyticsCoordinator
    private let tokenObject: TokenObject
    private var viewModel: TokensCardViewModel
    private let tokensStorage: TokensDataStore
    private let account: Wallet
    private let header = TokenCardsViewControllerHeader()
    private let roundedBackground = RoundedBackground()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 3))
    //TODO this wouldn't scale if there are many cells
    //Cache the cells used by position so we aren't dequeuing the standard UITableView way. This is so the webviews load the correct values, especially when scrolling
    private var cells = [Int: TokenCardTableViewCellWithCheckbox]()
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
        let tokenType = NonFungibleFromJsonSupportedTokenHandling(token: tokenObject)
        switch tokenType {
        case .supported:
            return true
        case .notSupported:
            return false
        }
    }

    init(analyticsCoordinator: AnalyticsCoordinator, tokenObject: TokenObject, account: Wallet, tokensStorage: TokensDataStore, assetDefinitionStore: AssetDefinitionStore, viewModel: TokensCardViewModel) {
        self.analyticsCoordinator = analyticsCoordinator
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

        tableView.register(TokenCardTableViewCellWithCheckbox.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.tableHeaderView = header
        tableView.estimatedRowHeight = TokensCardViewController.anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10
        roundedBackground.addSubview(tableView)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        roundedBackground.addSubview(footerBar)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            footerBar.anchorsConstraint(to: view),
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
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
        ])
        header.setNeedsLayout()
        header.layoutIfNeeded()
        tableView.tableHeaderView = header

        if let selectedTokenHolder = selectedTokenHolder {
            buttonsBar.configure(.combined(buttons: viewModel.actions.count))
            buttonsBar.viewController = self

            for (action, button) in zip(viewModel.actions, buttonsBar.buttons) {
                button.setTitle(action.name, for: .normal)
                button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
                switch account.type {
                case .real:
                    if let selection = action.activeExcludingSelection(selectedTokenHolders: [selectedTokenHolder], forWalletAddress: account.address) {
                        if selection.denial == nil {
                            button.displayButton = false
                        }
                    }
                case .watch:
                    button.isEnabled = false
                }
            }
        } else {
            buttonsBar.configuration = .empty
        }

        sizingCell = nil
        tableView.reloadData()
    }

    override
    func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: R.image.backWhite(), style: .plain, target: self, action: #selector(didTapCancelButton))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
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
        let transactionType = TransactionType.erc875Token(viewModel.token, tokenHolders: [selectedTokenHolder])
        delegate?.didPressSell(tokenHolder: selectedTokenHolder, for: .send(type: .transaction(transactionType)), in: self)
    }

    func transfer() {
        guard let selectedTokenHolder = selectedTokenHolder else { return }
        let transactionType = TransactionType(token: viewModel.token, tokenHolders: [selectedTokenHolder])
        delegate?.didPressTransfer(token: viewModel.token, tokenHolder: selectedTokenHolder, for: .send(type: .transaction(transactionType)), in: self)
    }

    private func handle(action: TokenInstanceAction) {
        guard let tokenHolder = selectedTokenHolder else { return }
        switch action.type {
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            break
        case .nftRedeem:
            redeem()
        case .nftSell:
            sell()
        case .nonFungibleTransfer:
            transfer()
        case .tokenScript:
            if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: account.address) {
                if let denialMessage = selection.denial {
                    UIAlertController.alert(
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
                delegate?.didTap(action: action, tokenHolder: tokenHolder, viewController: self)
            }
        }
    }

    //TODO multi-selection. Only supports selecting one tokenHolder for now
    @objc private func actionButtonTapped(sender: UIButton) {
        let actions = viewModel.actions
        for (action, button) in zip(actions, buttonsBar.buttons) where button == sender {
            handle(action: action)
            break
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
        switch OpenSeaBackedNonFungibleTokenHandling(token: viewModel.token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
        case .backedByOpenSea:
            if let indexPath = indexPaths.first(where: { viewModel.item(for: $0).areDetailsVisible }) {
                tableview.scrollToRow(at: indexPath, at: .top, animated: false)
            }
        case .notBackedByOpenSea:
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
        return tokenHolder.values.imageUrlUrlValue != nil
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

    ///TokenScript views might take some time to finish rendering and be performance intensive, so we render the first row in a sizing cell to figure out the height. This assumes that every row has the same height.
    ///Have to be careful that it works correctly with tokens that don't have TokenScript and also those backed by OpenSea
    private func createSizingCell() {
        guard sizingCell == nil else { return }
        guard viewModel.numberOfItems() > 0 else { return }
        let indexPath = IndexPath(row: 0, section: 0)
        let tokenHolder = viewModel.item(for: indexPath)

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: tokenObject, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        let cell = TokenCardTableViewCellWithCheckbox()
        sizingCell = cell
        var rowView: TokenCardRowViewProtocol & UIView
        switch tokenType {
        case .backedByOpenSea:
            rowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified, showCheckbox: cell.showCheckbox())
        case .notBackedByOpenSea:
            rowView = {
                if let rowView = cell.rowView {
                    //Reuse for performance (because webviews are created)
                    return rowView
                } else {
                    let rowView = TokenCardRowView(analyticsCoordinator: analyticsCoordinator, server: server, tokenView: .viewIconified, showCheckbox: cell.showCheckbox(), assetDefinitionStore: assetDefinitionStore)
                    rowView.delegate = self
                    return rowView
                }
            }()
        }
        rowView.bounds = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: TokensCardViewController.anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10)
        rowView.setNeedsLayout()
        rowView.layoutIfNeeded()
        rowView.shouldOnlyRenderIfHeightIsCached = false
        cell.delegate = self
        cell.rowView = rowView

        cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width, tokenView: .viewIconified), assetDefinitionStore: assetDefinitionStore)
        cell.isCheckboxVisible = isMultipleSelectionMode
        let hasAddedGestureRecognizer = cell.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } ?? false
        if !hasAddedGestureRecognizer {
            cell.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPressedTokenInstanceIconified)))
        }
    }

    private func reusableCell(forRowAt row: Int) -> TokenCardTableViewCellWithCheckbox {
        cells[row, default: TokenCardTableViewCellWithCheckbox(frame: .zero)]
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
    //Hide the header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    public func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfItems()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tokenHolder = viewModel.item(for: indexPath)

        if indexPath.section == 0 {
            createSizingCell()
        }

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: tokenObject, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        let cell = reusableCell(forRowAt: indexPath.row)
        var rowView: TokenCardRowViewProtocol & UIView
        switch tokenType {
        case .backedByOpenSea:
            rowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified, showCheckbox: cell.showCheckbox())
        case .notBackedByOpenSea:
            rowView = {
                if let rowView = cell.rowView {
                    //Reuse for performance (because webviews are created)
                    return rowView
                } else {
                    let rowView = TokenCardRowView(analyticsCoordinator: analyticsCoordinator, server: server, tokenView: .viewIconified, showCheckbox: cell.showCheckbox(), assetDefinitionStore: assetDefinitionStore)
                    //Important not to assign a delegate because we don't use actual cells to figure out the height. We use a sizing cell instead
                    return rowView
                }
            }()
        }
        //For performance, we use a sizing cell to figure out the height of a cell first and don't render actual cells until we know (cache) the height
        rowView.shouldOnlyRenderIfHeightIsCached = true
        cell.delegate = self
        cell.rowView = rowView
        cell.configure(viewModel: .init(tokenHolder: tokenHolder, cellWidth: tableView.frame.size.width, tokenView: .viewIconified), assetDefinitionStore: assetDefinitionStore)
        cell.isCheckboxVisible  = isMultipleSelectionMode
        let hasAddedGestureRecognizer = cell.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } ?? false
        if !hasAddedGestureRecognizer {
            cell.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(longPressedTokenInstanceIconified)))
        }
        return cell
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

extension TokensCardViewController: BaseTokenCardTableViewCellDelegate {
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

extension TokensCardViewController: TokenCardRowViewDelegate {
    func heightChangedFor(tokenCardRowView: TokenCardRowView) {
        guard let visibleRows = tableView.indexPathsForVisibleRows else { return }
        //Important to not reload the entire table due to poor performance
        UIView.setAnimationsEnabled(false)
        tableView.beginUpdates()
        tableView.reloadRows(at: visibleRows, with: .none)
        tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }
}

