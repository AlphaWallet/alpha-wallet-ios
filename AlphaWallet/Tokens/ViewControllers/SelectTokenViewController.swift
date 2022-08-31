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
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(FungibleTokenViewCell.self)
        tableView.register(EthTokenViewCell.self)
        tableView.register(NonFungibleTokenViewCell.self)
        tableView.estimatedRowHeight = 100
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false

        return tableView
    }()
    private lazy var dataSource = makeDataSource()
    private (set) lazy var headerView: ConfirmationHeaderView = {
        let view = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
        view.isHidden = true

        return view
    }()
    private let appear = PassthroughSubject<Void, Never>()
    private let fetch = PassthroughSubject<Void, Never>()
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

        loadingView = LoadingView.tokenSelectionLoadingView()
        emptyView = EmptyView.tokensEmptyView(completion: { [fetch] in
            fetch.send(())
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.applyTintAdjustment()
        navigationController?.navigationBar.prefersLargeTitles = false
        hidesBottomBarWhenPushed = true

        appear.send(())
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func bind(viewModel: SelectTokenViewModel) {
        title = viewModel.navigationTitle
        view.backgroundColor = viewModel.backgroundColor
        tableView.backgroundColor = viewModel.backgroundColor

        let input = SelectTokenViewModelInput(
            appear: appear.eraseToAnyPublisher(),
            fetch: fetch.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState.sink { [weak self] state in
            switch state.loadingState {
            case .idle:
                break
            case .beginLoading:
                self?.startLoading(animated: false)
            case .endLoading:
                self?.endLoading(animated: false)
            }
            self?.applySnapshot(with: state.views, animate: false)
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

        guard let token = viewModel.selectTokenViewModel(at: indexPath) else { return }
        delegate?.controller(self, didSelectToken: token)
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

    private func applySnapshot(with viewModels: [SelectTokenViewModel.ViewModelType], animate: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<SelectTokenViewModel.Section, SelectTokenViewModel.ViewModelType>()
        snapshot.appendSections([.tokens])
        snapshot.appendItems(viewModels, toSection: .tokens)

        dataSource.apply(snapshot, animatingDifferences: animate)
    }
}
