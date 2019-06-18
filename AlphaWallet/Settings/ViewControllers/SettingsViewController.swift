// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Eureka
import StoreKit
import MessageUI

protocol SettingsViewControllerDelegate: class, CanOpenURL {
    func didAction(action: AlphaWalletSettingsAction, in viewController: SettingsViewController)
    func assetDefinitionsOverrideViewController(for: SettingsViewController) -> UIViewController?
    func consoleViewController(for: SettingsViewController) -> UIViewController?
}

class SettingsViewController: FormViewController {
    private let lock = Lock()
    private var isPasscodeEnabled: Bool {
        return lock.isPasscodeSet
    }
    private lazy var viewModel: SettingsViewModel = {
        return SettingsViewModel(isDebug: isDebug)
    }()
    private let account: Wallet

    weak var delegate: SettingsViewControllerDelegate?

    init(account: Wallet) {
        self.account = account
        super.init(style: .plain)
        title = R.string.localizable.aSettingsNavigationTitle()
    }
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Colors.appBackground
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground

        form = createSection(withTitle: "")

        <<< AppFormAppearance.alphaWalletSettingsButton {
            $0.title = R.string.localizable.aSettingsContentsMyWalletAddress()
        }.onCellSelection { [unowned self] _, _ in
            self.delegate?.didAction(action: .myWalletAddress, in: self)
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
            cell.imageView?.image = R.image.settings_wallet1()?.withRenderingMode(.alwaysTemplate)
            cell.accessoryType = .disclosureIndicator
        }

        <<< AppFormAppearance.alphaWalletSettingsButton { button in
            button.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .wallets)
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { [weak self] cell, _ in
            guard let strongSelf = self else { return }
            cell.imageView?.image = R.image.settings_wallet()?.withRenderingMode(.alwaysTemplate)
            cell.textLabel?.text = R.string.localizable.settingsWalletsButtonTitle()
            cell.detailTextLabel?.text = strongSelf.account.address.eip55String
            cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle
            cell.accessoryType = .disclosureIndicator
        }

        <<< AppFormAppearance.alphaWalletSettingsButton { button in
            button.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .locales)
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { [weak self] cell, _ in
            guard let strongSelf = self else { return }
            cell.imageView?.image = R.image.settings_language()?.withRenderingMode(.alwaysTemplate)
            cell.textLabel?.text = strongSelf.viewModel.localeTitle
            cell.detailTextLabel?.text = AppLocale(id: Config.getLocale()).displayName
            cell.accessoryType = .disclosureIndicator
        }

        <<< AlphaWalletSettingsSwitchRow { [weak self] in
            $0.title = self?.viewModel.passcodeTitle
            $0.value = self?.isPasscodeEnabled
        }.onChange { [unowned self] row in
            if row.value == true {
                self.setPasscode { result in
                    row.value = result
                    row.updateCell()
                }
            } else {
                self.lock.deletePasscode()
            }
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
            cell.imageView?.image = R.image.settings_lock()?.withRenderingMode(.alwaysTemplate)
        }

        +++ createSection(withTitle: R.string.localizable.settingsAdvancedTitle())
        <<< AppFormAppearance.alphaWalletSettingsButton { button in
            button.cellStyle = .value1
        }.onCellSelection { [unowned self] _, _ in
            self.run(action: .enabledServers)
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { cell, _ in
            cell.imageView?.image = R.image.settings_server()?.withRenderingMode(.alwaysTemplate)
            cell.textLabel?.text = R.string.localizable.settingsEnabledNetworksButtonTitle()
            cell.accessoryType = .disclosureIndicator
        }
        <<< AppFormAppearance.alphaWalletSettingsButton { row in
            row.cellStyle = .value1
            row.presentationMode = .show(controllerProvider: ControllerProvider<UIViewController>.callback {
                self.delegate?.assetDefinitionsOverrideViewController(for: self) ?? UIViewController()
            }, onDismiss: { _ in
            })
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { cell, _ in
            cell.textLabel?.text = "    \(R.string.localizable.aHelpAssetDefinitionOverridesTitle())"
            cell.accessoryType = .disclosureIndicator
        }
        <<< AppFormAppearance.alphaWalletSettingsButton { row in
            row.cellStyle = .value1
            row.presentationMode = .show(controllerProvider: ControllerProvider<UIViewController>.callback {
                self.delegate?.consoleViewController(for: self) ?? UIViewController()
            }, onDismiss: { _ in
            })
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { cell, _ in
            cell.textLabel?.text = "    \(R.string.localizable.aConsoleTitle())"
            cell.accessoryType = .disclosureIndicator
        }
        <<< AppFormAppearance.alphaWalletSettingsButton {
            $0.title = "    \(R.string.localizable.aSettingsContentsClearDappBrowserCache())"
        }.onCellSelection { [unowned self] _, _ in
            self.delegate?.didAction(action: .clearDappBrowserCache, in: self)
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }

        +++ createSection(withTitle: R.string.localizable.settingsContactUsTitle())

        <<< linkProvider(type: .telegram)
        <<< linkProvider(type: .twitter)
        <<< linkProvider(type: .reddit)
        <<< linkProvider(type: .facebook)
        <<< AppFormAppearance.alphaWalletSettingsButton { row in
            row.cellStyle = .value1
            row.presentationMode = .show(controllerProvider: ControllerProvider<UIViewController>.callback {
                let vc = HelpViewController(delegate: self)
                return vc
            }, onDismiss: { _ in
            })
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
        }.cellUpdate { cell, _ in
            cell.imageView?.image = R.image.tab_help()?.withRenderingMode(.alwaysTemplate)
            cell.textLabel?.text = R.string.localizable.aHelpNavigationTitle()
            cell.accessoryType = .disclosureIndicator
        }

        +++ createSection(withTitle: "")

        <<< AlphaWalletSettingsTextRow {
            $0.disabled = true
        }.cellSetup { cell, _ in
            cell.mainLabel.text = R.string.localizable.settingsVersionLabelTitle()
            cell.subLabel.text = Bundle.main.fullVersion
        }
    }

    func setPasscode(completion: ((Bool) -> Void)? = .none) {
        let lock = LockCreatePasscodeCoordinator(navigationController: navigationController!, model: LockCreatePasscodeViewModel())
        lock.start()
        lock.lockViewController.willFinishWithResult = { result in
            completion?(result)
            lock.stop()
        }
    }

    private func linkProvider(
            type: URLServiceProvider
    ) -> AlphaWalletSettingsButtonRow {
        return AppFormAppearance.alphaWalletSettingsButton {
            $0.title = type.title
        }.onCellSelection { [unowned self] _, _ in
            if let localURL = type.localURL, UIApplication.shared.canOpenURL(localURL) {
                UIApplication.shared.open(localURL, options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]), completionHandler: .none)
            } else {
                self.delegate?.didPressOpenWebPage(type.remoteURL, in: self)
            }
        }.cellSetup { cell, _ in
            cell.imageView?.tintColor = Colors.appBackground
            cell.imageView?.image = type.image?.withRenderingMode(.alwaysTemplate)
        }
    }

    func run(action: AlphaWalletSettingsAction) {
        delegate?.didAction(action: action, in: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createSection(withTitle title: String) -> Section {
        return Section() { section in
            var header = HeaderFooterView<SettingsHeaderView>(.class)
            header.onSetupView = { view, _ in
                view.title = title
            }
            section.header = header
        }
    }
}

extension SettingsViewController: HelpViewControllerDelegate {
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

// Helper function inserted by Swift 4.2 migrator.
private func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(_ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value) })
}
