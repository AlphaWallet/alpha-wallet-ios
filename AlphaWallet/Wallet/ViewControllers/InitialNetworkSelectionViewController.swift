//
//  InitialNetworkSelectionViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/5/22.
//

import UIKit

protocol InitialNetworkSelectionViewControllerDelegateProtocol: class {
    func didSelect(networks: [RPCServer], in viewController: InitialNetworkSelectionViewController)
}
/*         let headerView: EnableServersHeaderView
 switch sections[section] {
 case .testnet:
 headerView = headers.testnet
 headerView.configure(mode: .testnet, isEnabled: viewModel.mode == .testnet)
 case .mainnet:
 headerView = headers.mainnet
 headerView.configure(mode: .mainnet, isEnabled: viewModel.mode == .mainnet)
 }
 headerView.delegate = self
 return headerView

 */
class InitialNetworkSelectionViewController: UIViewController {

    // MARK: - Accessors (Private)

    private var selectionView: InitialNetworkSelectionView {
        self.view as! InitialNetworkSelectionView
    }

    // MARK: - variables (Private)

    private var viewModel: InitialNetworkSelectionViewModel
    weak var delegate: InitialNetworkSelectionViewControllerDelegateProtocol?

    init(model: InitialNetworkSelectionCollectionModel = InitialNetworkSelectionCollectionModel()) {
        viewModel = InitialNetworkSelectionViewModel(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureController()
    }

    override func loadView() {
        self.view = InitialNetworkSelectionView()
    }

    // MARK: - Setup

    private func configureController() {
        title = R.string.localizable.settingsSelectActiveNetworksTitle()
        selectionView.continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        selectionView.continueButton.addTarget(self, action: #selector(continuePressed(sender:)), for: .touchUpInside)
        selectionView.tableViewDelegate = viewModel
        selectionView.tableViewDataSource = viewModel
        selectionView.searchBarDelegate = viewModel
        selectionView.configure(viewModel: viewModel)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: InitialNetworkSelectionViewModel.ReloadTableViewNotification, object: viewModel)
        NotificationCenter.default.addObserver(self, selector: #selector(changeContinueButtonState(notification:)), name: InitialNetworkSelectionViewModel.ChangeSelectedCountNotification, object: viewModel)
        changeContinueButtonState(!viewModel.selected.isEmpty)
    }

    // MARK: - selectors

    @objc private func continuePressed(sender: UIButton) {
        // FIXME: - Add code to save networks
        NSLog("Ouch")
    }

    @objc private func reloadTable() {
        selectionView.reloadTableView()
    }

    @objc private func changeContinueButtonState(notification: Notification) {
        if let selectedCount = notification.userInfo?[InitialNetworkSelectionViewModel.ChangeSelectedKey] as? Int {
            changeContinueButtonState(selectedCount > 0)
        }
    }

    private func changeContinueButtonState(_ state: Bool) {
        selectionView.continueButton.isEnabled = state
    }
}
