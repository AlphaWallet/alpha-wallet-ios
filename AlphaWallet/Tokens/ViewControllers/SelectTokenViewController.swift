//
//  SelectTokenCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import StatefulViewController
import Combine
import AlphaWalletFoundation

protocol SelectTokenViewControllerDelegate: AnyObject {
    func controller(_ controller: SelectTokenViewController, didSelectToken token: Token)
}

class SelectTokenViewController: UIViewController {
    private let viewModel: SelectTokenViewModel
    private var cancellable = Set<AnyCancellable>()
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(FungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.estimatedRowHeight = 100
        tableView.separatorInset = .zero
        tableView.delegate = self

        return tableView
    }()
    private lazy var dataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let fetch = PassthroughSubject<Void, Never>()

    weak var delegate: SelectTokenViewControllerDelegate?

    init(viewModel: SelectTokenViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])

        loadingView = LoadingView.tokenSelectionLoadingView()
        emptyView = EmptyView.tokensEmptyView(completion: { [fetch] in
            fetch.send(())
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.applyTintAdjustment()
        navigationController?.navigationBar.prefersLargeTitles = false
        hidesBottomBarWhenPushed = true

        willAppear.send(())
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func bind(viewModel: SelectTokenViewModel) {
        let input = SelectTokenViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            fetch: fetch.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState
            .sink { [weak self, dataSource, navigationItem] viewState in
                dataSource.apply(viewState.snapshot, animatingDifferences: false)

                switch viewState.loadingState {
                case .idle:
                    break
                case .beginLoading:
                    self?.startLoading(animated: false)
                case .endLoading:
                    self?.endLoading(animated: false)
                }
                navigationItem.title = viewState.title
            }.store(in: &cancellable)
    }
}

extension SelectTokenViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension SelectTokenViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        Task { @MainActor in
            guard let token = await viewModel.selectTokenViewModel(viewModel: dataSource.item(at: indexPath)) else { return }
            delegate?.controller(self, didSelectToken: token)
        }
    }
}

extension SelectTokenViewController {
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

fileprivate extension SelectTokenViewController {
    func makeDataSource() -> TableViewDiffableDataSource<SelectTokenViewModel.Section, SelectTokenViewModel.ViewModelType> {
        return TableViewDiffableDataSource(tableView: tableView, cellProvider: { tableView, indexPath, viewModel in
            switch viewModel {
            case .nativeCryptocurrency(let viewModel):
                let cell: EthTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                return cell
            case .fungible(let viewModel):
                let cell: FungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                return cell
            case .nonFungible(let viewModel):
                let cell: NonFungibleTokenViewCell = tableView.dequeueReusableCell(for: indexPath)
                cell.configure(viewModel: viewModel)

                return cell
            }
        })
    }
}
