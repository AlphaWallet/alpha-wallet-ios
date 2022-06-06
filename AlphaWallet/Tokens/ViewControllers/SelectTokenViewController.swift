//
//  SelectTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import StatefulViewController
import Combine

protocol SelectTokenViewControllerDelegate: AnyObject {
    func controller(_ controller: SelectTokenViewController, didSelectToken token: Token)
}

class SelectTokenViewController: UIViewController {
    private let viewModel: SelectTokenViewModel
    private var cancellable = Set<AnyCancellable>()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(FungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.dataSource = self
        tableView.estimatedRowHeight = 100
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()

    private (set) lazy var headerView: ConfirmationHeaderView = {
        let view = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
        view.isHidden = true

        return view
    }()

    weak var delegate: SelectTokenViewControllerDelegate?

    init(viewModel: SelectTokenViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let stackView = [headerView, tableView].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view)
        ])

        errorView = ErrorView(onRetry: { [weak self] in
            self?.fetchTokens()
        })

        loadingView = LoadingView(insets: .init(top: Style.SearchBar.height, left: 0, bottom: 0, right: 0))
        emptyView = EmptyView.tokensEmptyView(completion: { [weak self] in
            self?.fetchTokens()
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bind(viewModel: viewModel)
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.applyTintAdjustment()
        navigationController?.navigationBar.prefersLargeTitles = false
        hidesBottomBarWhenPushed = true

        fetchTokens()
    }

    private func fetchTokens() {
        startLoading()
        viewModel.fetch()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func bind(viewModel: SelectTokenViewModel) {
        title = viewModel.navigationTitle
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor

        viewModel.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self]  _ in
                self?.tableView.reloadData()
                self?.endLoading()
            }.store(in: &cancellable)
    }
}

extension SelectTokenViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.numberOfItems() > 0
    }
}

extension SelectTokenViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let token = viewModel.selectToken(at: indexPath)
        delegate?.controller(self, didSelectToken: token)
    }
}

extension SelectTokenViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel.viewModel(for: indexPath) {
        case .nativeCryptocurrency(let viewModel):
            let cell: EthTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        case .erc20(let viewModel):
            let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        case .nonFungible(let viewModel):
            let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfItems()
    }

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
}
