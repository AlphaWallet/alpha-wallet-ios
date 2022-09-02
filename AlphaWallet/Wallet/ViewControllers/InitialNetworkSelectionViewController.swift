//
//  InitialNetworkSelectionViewController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/5/22.
//

import UIKit
import AlphaWalletFoundation

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
        viewModel.delegate = self
    }

    // MARK: - selectors

    @objc private func continuePressed(sender: UIButton) {
        let selectedServers = viewModel.selected
        guard !selectedServers.isEmpty else { return }
        delegate?.didSelect(servers: selectedServers, in: self)
    }

}

extension InitialNetworkSelectionViewController: InitialNetworkSelectionViewModelDelegate {

    func reloadTable() {
        selectionView.reloadTableView()
    }

    func changeSelectionCount(rowCount: Int) {
        selectionView.continueButton.isEnabled = rowCount > 0
    }

    func promptUserForTestnet(viewModel delegate: InitialNetworkSelectionViewModel) {
        let prompt = PromptViewController()
        prompt.configure(viewModel: .init(title: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetTitle(), description: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetDescription(), buttonTitle: R.string.localizable.settingsEnabledNetworksPromptEnableTestnetButtonTitle()))
        prompt._delegate = delegate
        present(prompt, animated: true)
    }

}
