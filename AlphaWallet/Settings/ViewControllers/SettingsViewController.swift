// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import PromiseKit

protocol SettingsViewControllerDelegate: class, CanOpenURL {
    func settingsViewControllerAdvancedSettingsSelected(in controller: SettingsViewController)
    func settingsViewControllerChangeWalletSelected(in controller: SettingsViewController)
    func settingsViewControllerMyWalletAddressSelected(in controller: SettingsViewController)
    func settingsViewControllerBackupWalletSelected(in controller: SettingsViewController)
    func settingsViewControllerShowSeedPhraseSelected(in controller: SettingsViewController)
    func settingsViewControllerWalletConnectSelected(in controller: SettingsViewController)
    func settingsViewControllerNameWalletSelected(in controller: SettingsViewController)
    func settingsViewControllerBlockscanChatSelected(in controller: SettingsViewController)
    func settingsViewControllerActiveNetworksSelected(in controller: SettingsViewController)
    func settingsViewControllerHelpSelected(in controller: SettingsViewController)
}

class SettingsViewController: UIViewController {
    private let lock = Lock()
    private var config: Config
    private let keystore: Keystore
    private let account: Wallet
    private let analyticsCoordinator: AnalyticsCoordinator
    private let domainResolutionService: DomainResolutionServiceType
    private let promptBackupWalletViewHolder = UIView()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(SettingTableViewCell.self)
        tableView.register(SwitchTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = Metrics.anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()

        return tableView
    }()
    private var viewModel: SettingsViewModel

    weak var delegate: SettingsViewControllerDelegate?
    var promptBackupWalletView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let promptBackupWalletView = promptBackupWalletView {
                promptBackupWalletView.translatesAutoresizingMaskIntoConstraints = false
                promptBackupWalletViewHolder.addSubview(promptBackupWalletView)
                NSLayoutConstraint.activate([
                    promptBackupWalletView.leadingAnchor.constraint(equalTo: promptBackupWalletViewHolder.leadingAnchor, constant: 7),
                    promptBackupWalletView.trailingAnchor.constraint(equalTo: promptBackupWalletViewHolder.trailingAnchor, constant: -7),
                    promptBackupWalletView.topAnchor.constraint(equalTo: promptBackupWalletViewHolder.topAnchor, constant: 7),
                    promptBackupWalletView.bottomAnchor.constraint(equalTo: promptBackupWalletViewHolder.bottomAnchor, constant: 0),
                ])
                tabBarItem.badgeValue = "1"
                showPromptBackupWalletViewAsTableHeaderView()
            } else {
                hidePromptBackupWalletView()
                tabBarItem.badgeValue = nil
            }
        }
    }

    init(config: Config, keystore: Keystore, account: Wallet, analyticsCoordinator: AnalyticsCoordinator, domainResolutionService: DomainResolutionServiceType) {
        self.config = config
        self.keystore = keystore
        self.account = account
        self.analyticsCoordinator = analyticsCoordinator
        self.domainResolutionService = domainResolutionService
        viewModel = SettingsViewModel(account: account, keystore: keystore, blockscanChatUnreadCount: nil)
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = R.string.localizable.aSettingsNavigationTitle()
        view.backgroundColor = GroupedTable.Color.background
        navigationItem.largeTitleDisplayMode = .automatic
        tableView.backgroundColor = GroupedTable.Color.background

        if promptBackupWalletView == nil {
            hidePromptBackupWalletView()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reflectCurrentWalletSecurityLevel()
    }

    func configure(blockscanChatUnreadCount: Int?) {
        viewModel = SettingsViewModel(account: account, keystore: keystore, blockscanChatUnreadCount: blockscanChatUnreadCount)
        tableView.reloadData()
        if let unreadCount = viewModel.blockscanChatUnreadCount, unreadCount > 0 {
            tabBarItem.badgeValue = String(unreadCount)
        } else {
            tabBarItem.badgeValue = nil
        }
    }

    private func showPromptBackupWalletViewAsTableHeaderView() {
        let size = promptBackupWalletViewHolder.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        promptBackupWalletViewHolder.bounds.size.height = size.height

        tableView.tableHeaderView = promptBackupWalletViewHolder
    }

    private func hidePromptBackupWalletView() {
        tableView.tableHeaderView = nil
    }

    private func reflectCurrentWalletSecurityLevel() {
        tableView.reloadData()
    }

    private func setPasscode(completion: ((Bool) -> Void)? = .none) {
        guard let navigationController = navigationController else { return }
        let viewModel = LockCreatePasscodeViewModel()
        let lock = LockCreatePasscodeCoordinator(navigationController: navigationController, model: viewModel)
        lock.start()
        lock.lockViewController.willFinishWithResult = { result in
            completion?(result)
            lock.stop()
        }
    }

    private func configureChangeWalletCellWithResolvedENS(_ row: SettingsWalletRow, indexPath: IndexPath, cell: SettingTableViewCell) {
        cell.configure(viewModel: .init(
            titleText: row.title,
            subTitleText: viewModel.addressReplacedWithENSOrWalletName(),
            icon: row.icon)
        )

        firstly {
            GetWalletName(config: config, domainResolutionService: domainResolutionService).getName(forAddress: account.address)
        }.done { [weak self] name in
            //NOTE check if still correct cell, since this is async
            guard let strongSelf = self, cell.indexPath == indexPath else { return }
            let viewModel: SettingTableViewCellViewModel = .init(
                    titleText: row.title,
                    subTitleText: strongSelf.viewModel.addressReplacedWithENSOrWalletName(name),
                    icon: row.icon
            )
            cell.configure(viewModel: viewModel)
        }.cauterize()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension SettingsViewController: CanOpenURL {

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension SettingsViewController: SwitchTableViewCellDelegate {

    func cell(_ cell: SwitchTableViewCell, switchStateChanged isOn: Bool) {
        guard let indexPath = cell.indexPath else { return }

        switch viewModel.sections[indexPath.section] {
        case .system(let rows):
            switch rows[indexPath.row] {
            case .passcode:
                if isOn {
                    setPasscode { result in
                        cell.isOn = result
                    }
                } else {
                    lock.deletePasscode()
                }
            case .notifications, .selectActiveNetworks, .advanced:
                break
            }
        case .help, .tokenStandard, .version, .wallet:
            break
        }
    }
}

extension SettingsViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.numberOfSections()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfSections(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.sections[indexPath.section] {
        case .system(let rows):
            let row = rows[indexPath.row]
            switch row {
            case .passcode:
                let cell: SwitchTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(
                    titleText: viewModel.passcodeTitle,
                    icon: R.image.biometrics()!,
                    value: lock.isPasscodeSet)
                )
                cell.delegate = self

                return cell
            case .notifications, .selectActiveNetworks, .advanced:
                let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: .init(settingsSystemRow: row))

                return cell
            }
        case .help:
            let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: .init(titleText: R.string.localizable.settingsSupportTitle(), icon: R.image.support()!))

            return cell
        case .wallet(let rows):
            let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            let row = rows[indexPath.row]
            switch row {
            case .changeWallet:
                configureChangeWalletCellWithResolvedENS(row, indexPath: indexPath, cell: cell)

                return cell
            case .backup:
                cell.configure(viewModel: .init(settingsWalletRow: row))
                let walletSecurityLevel = PromptBackupCoordinator(keystore: keystore, wallet: account, config: .init(), analyticsCoordinator: analyticsCoordinator).securityLevel
                cell.accessoryView = walletSecurityLevel.flatMap { WalletSecurityLevelIndicator(level: $0) }
                cell.accessoryType = .disclosureIndicator

                return cell
            case .showMyWallet, .showSeedPhrase, .walletConnect, .nameWallet, .blockscanChat:
                cell.configure(viewModel: .init(settingsWalletRow: row))

                return cell
            }
        case .tokenStandard, .version:
            return UITableViewCell()
        }
    }
}

extension SettingsViewController: UITableViewDelegate {

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView: SettingViewHeader = SettingViewHeader()
        let viewModel = SettingViewHeaderViewModel(section: self.viewModel.sections[section])
        headerView.configure(viewModel: viewModel)

        return headerView
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch viewModel.sections[indexPath.section] {
        case .wallet(let rows):
            switch rows[indexPath.row] {
            case .backup:
                delegate?.settingsViewControllerBackupWalletSelected(in: self)
            case .changeWallet:
                delegate?.settingsViewControllerChangeWalletSelected(in: self)
            case .showMyWallet:
                delegate?.settingsViewControllerMyWalletAddressSelected(in: self)
            case .showSeedPhrase:
                delegate?.settingsViewControllerShowSeedPhraseSelected(in: self)
            case .walletConnect:
                delegate?.settingsViewControllerWalletConnectSelected(in: self)
            case .nameWallet:
                delegate?.settingsViewControllerNameWalletSelected(in: self)
            case .blockscanChat:
                delegate?.settingsViewControllerBlockscanChatSelected(in: self)
            }
        case .system(let rows):
            switch rows[indexPath.row] {
            case .advanced:
                delegate?.settingsViewControllerAdvancedSettingsSelected(in: self)
            case .notifications, .passcode:
                break
            case .selectActiveNetworks:
                delegate?.settingsViewControllerActiveNetworksSelected(in: self)
            }
        case .help:
            delegate?.settingsViewControllerHelpSelected(in: self)
        case .tokenStandard:
            self.delegate?.didPressOpenWebPage(TokenScript.tokenScriptSite, in: self)
        case .version:
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let height = tableView.rowHeight
        switch viewModel.sections[indexPath.section] {
        case .wallet(let rows):
            let row = rows[indexPath.row]
            switch row {
            case .changeWallet:
                return Style.TableView.ChangeWalletCell.height
            default:
                return height
            }
        default:
            return height
        }
    }
}
