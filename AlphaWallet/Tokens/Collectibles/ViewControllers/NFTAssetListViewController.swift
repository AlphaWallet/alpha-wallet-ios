//
//  NFTAssetListViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import StatefulViewController
import AlphaWalletFoundation
import Combine

protocol NFTAssetListViewControllerDelegate: AnyObject {
    func didSelectTokenCard(in viewController: NFTAssetListViewController, tokenHolder: TokenHolder, tokenId: TokenId)
}

class NFTAssetListViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(ContainerTableViewCell.self)
        tableView.estimatedRowHeight = 100
        tableView.delegate = self
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    private let tokenCardViewFactory: TokenCardViewFactory
    private let roundedBackground = RoundedBackground()
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource = makeDataSource()
    private let appear = PassthroughSubject<Void, Never>()
    private let viewModel: NFTAssetListViewModel

    weak var delegate: NFTAssetListViewControllerDelegate?

    init(viewModel: NFTAssetListViewModel, tokenCardViewFactory: TokenCardViewFactory) {
        self.tokenCardViewFactory = tokenCardViewFactory
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        roundedBackground.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(roundedBackground)

        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: roundedBackground.bottomAnchor)
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        emptyView = EmptyView.nftAssetsEmptyView()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appear.send(())
    }

    private func reload() {
        startLoading(animated: false)
        endLoading(animated: false)
    }

    private func bind(viewModel: NFTAssetListViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor

        let input = NFTAssetListViewModelInput(appear: appear.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource, navigationItem] viewState in
                navigationItem.title = viewState.title
                dataSource.apply(viewState.snapshot, animatingDifferences: false)
                self.reload()
            }.store(in: &cancelable)
    }
}

extension NFTAssetListViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfSections > 0
    }
}

extension NFTAssetListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selection = viewModel.tokenHolderSelection(indexPath: indexPath)

        delegate?.didSelectTokenCard(in: self, tokenHolder: selection.tokenHolder, tokenId: selection.tokenId)
    }
}

fileprivate extension NFTAssetListViewController {
    private typealias DataSource = TableViewDiffableDataSource<NFTAssetListViewModel.Section, NFTAssetListViewModel.AssetViewState>
    
    private func makeDataSource() -> DataSource {
        return TableViewDiffableDataSource(tableView: tableView, cellProvider: { [tokenCardViewFactory] tableView, indexPath, viewModel in
            let cell: ContainerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.containerEdgeInsets = .zero
            cell.selectionStyle = viewModel.containerViewState.selectionStyle
            cell.backgroundColor = viewModel.containerViewState.backgroundColor
            cell.contentView.backgroundColor = viewModel.containerViewState.backgroundColor
            cell.accessoryType = viewModel.containerViewState.accessoryType

            let subview = tokenCardViewFactory.createTokenCardView(for: viewModel.tokenHolder, layout: viewModel.layout, listEdgeInsets: .init(top: 8, left: 16, bottom: 8, right: 16))
            subview.configure(tokenHolder: viewModel.tokenHolder, tokenId: viewModel.tokenId)
            cell.configure(subview: subview)

            return cell
        })
    }
}

extension NFTAssetListViewController {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
}
