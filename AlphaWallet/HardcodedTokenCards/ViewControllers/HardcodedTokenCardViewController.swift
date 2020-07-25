// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

protocol HardcodedTokenCardViewControllerDelegate: class, CanOpenURL {
    func didTapSend(forTransferType transferType: TransferType, inViewController viewController: HardcodedTokenCardViewController)
    func didTapReceive(forTransferType transferType: TransferType, inViewController viewController: HardcodedTokenCardViewController)
    func didTap(action: TokenInstanceAction, transferType: TransferType, viewController: HardcodedTokenCardViewController)
}

typealias HardcodedTokenCardRowFormatter = ([AttributeId: AssetInternalValue]) -> String
typealias HardcodedTokenCardRowFloatBlock = ([AttributeId: AssetInternalValue]) -> Float

//TODO fix for activities: remove and replace
class HardcodedTokenCardViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    lazy private var header = HardcodedTokenViewControllerHeaderView()
    private var viewModel: HardcodedTokenViewControllerViewModel
    private var tokenHolder: TokenHolder?
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let transferType: TransferType
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let buttonsBar = ButtonsBar(configuration: .combined(buttons: 2))
    private var values: [AttributeId: AssetInternalValue] = .init()
    private var refreshTimer = Timer()
    private let refreshInterval = 10.0

    weak var delegate: HardcodedTokenCardViewControllerDelegate?

    init(session: WalletSession, assetDefinition: AssetDefinitionStore, transferType: TransferType, viewModel: HardcodedTokenViewControllerViewModel) {
        self.session = session
        self.assetDefinitionStore = assetDefinition
        self.transferType = transferType
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true

        title = viewModel.title
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)


        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.register(HardcodedTokenCardCell.self)
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

        configure(viewModel: viewModel)
        scheduleRefresh()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    private func scheduleRefresh() {
        refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval, target: BlockOperation { [weak self] in
            self?.tokenHolder = nil
            self?.generateTokenHolder()
            self?.reloadAttributes()
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }

    private func configure(viewModel: HardcodedTokenViewControllerViewModel) {
        self.viewModel = viewModel
        view.backgroundColor = viewModel.backgroundColor

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
                //TODO fix for activities: This was needed so watch accounts display values too
                _ = generateTokenHolder()
            }
        }

        reloadHeader()
        reloadAttributes()
    }

    private func reloadHeader() {
        if let icon = viewModel.iconImage {
            header.tokenIconImageView.subscribable = icon
        }
        header.descriptionLabel.text = viewModel.description
        header.frame.size.height = header.systemLayoutSizeFitting(.zero).height
        tableView.tableHeaderView = header
    }

    private func reloadAttributes(isFirstUpdate: Bool = true) {
        guard let tokenHolder = tokenHolder else { return }
        let attributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        let resolvedAttributeNameValues = attributeValues.resolve { [weak self] values in
            guard let strongSelf = self else { return }
            strongSelf.values = strongSelf.values.merging(values) { _, new in new }
            strongSelf.header.balanceLabel.text = strongSelf.viewModel.headerValueFormatter(values)
            strongSelf.header.frame.size.height = strongSelf.header.systemLayoutSizeFitting(.zero).height
            strongSelf.tableView.tableHeaderView = strongSelf.header
            strongSelf.tableView.reloadData()

            guard isFirstUpdate else { return }
            strongSelf.reloadAttributes(isFirstUpdate: false)
        }
    }

    @objc private func send() {
        delegate?.didTapSend(forTransferType: transferType, inViewController: self)
    }

    @objc private func receive() {
        delegate?.didTapReceive(forTransferType: transferType, inViewController: self)
    }

    @objc private func actionButtonTapped(sender: UIButton) {
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
        guard let tokenObject = viewModel.token else { return nil }
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
                subscribable.subscribe { [weak self] value in
                    guard let strongSelf = self else { return }
                    strongSelf.configure(viewModel: strongSelf.viewModel)
                }
            }
        }


        let token = Token(tokenIdOrEvent: .tokenId(tokenId: hardcodedTokenIdForFungibles), tokenType: tokenObject.type, index: 0, name: tokenObject.name, symbol: tokenObject.symbol, status: .available, values: values)
        tokenHolder = TokenHolder(tokens: [token], contractAddress: tokenObject.contractAddress, hasAssetDefinition: true)
        return tokenHolder
    }
}

extension HardcodedTokenCardViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let (title: title, formatter: formatter, progressBlock: progressBlock) = viewModel.sections[indexPath.section].rows[indexPath.row]
        let cell: HardcodedTokenCardCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: .init(values: values, title: title, formatter: formatter, progressBlock: progressBlock))
        return cell
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        viewModel.sections.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.sections[section].rows.count ?? 0
    }
}

extension HardcodedTokenCardViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == viewModel.sections[indexPath.section].rows.count - 1 {
            return 90
        } else {
            return 60
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = HardcodedTokenCardTableSectionHeader()
        headerView.configure(title: viewModel.sections[section].section)
        return headerView
    }
}
