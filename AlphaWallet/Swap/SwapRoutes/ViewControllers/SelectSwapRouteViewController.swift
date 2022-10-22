//
//  SelectSwapRouteViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.09.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation
import StatefulViewController

final class SelectSwapRouteViewController: UIViewController {
    private let viewModel: SelectSwapRouteViewModel

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(SelectableSwapRouteTableViewCell.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = GroupedTable.Color.background

        return tableView
    }()
    private lazy var dataSource: SelectSwapRouteViewModel.RoutesDiffableDataSource = makeDataSource()
    private let appear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<IndexPath, Never>()
    private var cancelable = Set<AnyCancellable>()

    private lazy var swapRouteSummaryView: SwapRouteSummaryView = {
        let view = SwapRouteSummaryView(edgeInsets: .init(top: 20, left: 15, bottom: 15, right: 20), viewModel: viewModel.summaryViewModel)

        return view
    }()

    init(viewModel: SelectSwapRouteViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        tableView.delegate = self
        view.addSubview(tableView)
        NSLayoutConstraint.activate([tableView.anchorsConstraint(to: view)])
        view.backgroundColor = viewModel.backgroundColor
        emptyView = EmptyView.swapToolsEmptyView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appear.send(())
    }

    private func bind(viewModel: SelectSwapRouteViewModel) {
        let appear = appear
            .handleEvents(receiveOutput: { [weak self] _ in self?.startLoading() })
            .eraseToAnyPublisher()

        let input = SelectSwapRouteViewModelInput(
            appear: appear,
            selection: selection.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState
            .sink { [weak self] state in
                self?.navigationItem.title = state.title
                self?.dataSource.apply(state.snapshot, animatingDifferences: false)
                self?.endLoading()
            }.store(in: &cancelable)
    }
}

extension SelectSwapRouteViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension SelectSwapRouteViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selection.send(indexPath)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return swapRouteSummaryView
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
}

extension SelectSwapRouteViewController {
    private func makeDataSource() -> SelectSwapRouteViewModel.RoutesDiffableDataSource {
        SelectSwapRouteViewModel.RoutesDiffableDataSource(tableView: tableView) { tableView, indexPath, viewModel -> SelectableSwapRouteTableViewCell in
            let cell: SelectableSwapRouteTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}
