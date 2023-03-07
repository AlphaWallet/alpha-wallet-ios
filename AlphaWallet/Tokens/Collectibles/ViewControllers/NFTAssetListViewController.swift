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
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(ContainerTableViewCell.self)
        tableView.estimatedRowHeight = 100
        tableView.delegate = self
        tableView.separatorInset = .zero

        return tableView
    }()
    private let tokenCardViewFactory: TokenCardViewFactory
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let viewModel: NFTAssetListViewModel

    weak var delegate: NFTAssetListViewControllerDelegate?

    init(viewModel: NFTAssetListViewModel, tokenCardViewFactory: TokenCardViewFactory) {
        self.tokenCardViewFactory = tokenCardViewFactory
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view)
        ])

        emptyView = EmptyView.nftAssetsEmptyView()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

    private func reload() {
        startLoading(animated: false)
        endLoading(animated: false)
    }

    private func bind(viewModel: NFTAssetListViewModel) {
        let input = NFTAssetListViewModelInput(willAppear: willAppear.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource, navigationItem] viewState in
                navigationItem.title = viewState.title
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
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
    private func makeDataSource() -> NFTAssetListViewModel.DataSource {
        return NFTAssetListViewModel.DataSource(tableView: tableView, cellProvider: { [tokenCardViewFactory] tableView, indexPath, viewModel in
            let cell: ContainerTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.containerEdgeInsets = .zero
            cell.selectionStyle = viewModel.containerViewState.selectionStyle
            cell.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
            cell.contentView.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
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
