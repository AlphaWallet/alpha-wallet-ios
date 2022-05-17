//
//  InitialNetworkSelectionViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/5/22.
//

import UIKit

protocol InitialNetworkSelectionViewControllerDelegate: class {
    func didSelect(servers: [RPCServer], in viewController: InitialNetworkSelectionViewController)
}

class InitialNetworkSelectionViewController: UIViewController {

    // MARK: - Accessors (Private)

    private var selectionView: InitialNetworkSelectionView {
        self.view as! InitialNetworkSelectionView
    }

    // MARK: - variables (Private)

    private var viewModel: InitialNetworkSelectionViewModel

    // MARK: - variables (Public)

    weak var delegate: InitialNetworkSelectionViewControllerDelegate?

    init(model: InitialNetworkSelectionCollectionModel = InitialNetworkSelectionCollectionModel()) {
        viewModel = InitialNetworkSelectionViewModel(model: model)
        super.init(nibName: nil, bundle: nil)
        viewModel.set { rowCount in
            self.selectionView.setTableViewEmpty(isHidden: rowCount == 0)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }

    override func loadView() {
        self.view = InitialNetworkSelectionView()
    }

    // MARK: - Setup

    private func configure() {
        title = R.string.localizable.settingsSelectActiveNetworksTitle()
        selectionView.continueButton.setTitle(R.string.localizable.continue(), for: .normal)
        selectionView.continueButton.addTarget(self, action: #selector(continuePressed(sender:)), for: .touchUpInside)
        selectionView.tableViewDelegate = viewModel
        selectionView.tableViewDataSource = viewModel
        selectionView.searchBarDelegate = viewModel
        selectionView.configure(viewModel: viewModel)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadTable), name: InitialNetworkSelectionViewModel.ReloadTableViewNotification, object: viewModel)
        NotificationCenter.default.addObserver(self, selector: #selector(changeContinueButtonState(notification:)), name: InitialNetworkSelectionViewModel.ChangeSelectedCountNotification, object: viewModel)
        NotificationCenter.default.addObserver(self, selector: #selector(promptUser(notification:)), name: InitialNetworkSelectionViewModel.PromptNotification, object: viewModel)
        changeContinueButtonState(!viewModel.selected.isEmpty)
    }

    // MARK: - selectors

    @objc private func continuePressed(sender: UIButton) {
        let selectedServers = viewModel.selected
        guard !selectedServers.isEmpty else { return }
        delegate?.didSelect(servers: selectedServers, in: self)
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

    @objc private func promptUser(notification: Notification) {
        guard let delegate = notification.object as? InitialNetworkSelectionViewModel else { return }
        let prompt = PromptViewController()
        prompt.configure(viewModel: .init(title: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetTitle(), description: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetDescription(), buttonTitle: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetButtonTitle()))
        prompt._delegate = delegate
        present(prompt, animated: true)
    }

}
