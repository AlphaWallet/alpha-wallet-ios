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
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(SelectableSwapRouteTableViewCell.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.separatorInset = .zero
        tableView.delegate = self

        return tableView
    }()
    private lazy var dataSource: SelectSwapRouteViewModel.DataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<IndexPath, Never>()
    private var cancelable = Set<AnyCancellable>()

    private lazy var swapRouteSummaryView: SwapRouteSummaryView = {
        let view = SwapRouteSummaryView(edgeInsets: .init(top: 20, left: 15, bottom: 15, right: 20), viewModel: viewModel.summaryViewModel)

        return view
    }()

    init(viewModel: SelectSwapRouteViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([tableView.anchorsConstraint(to: view)])

        emptyView = EmptyView.swapToolsEmptyView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    private func bind(viewModel: SelectSwapRouteViewModel) {
        let willAppear = willAppear
            .handleEvents(receiveOutput: { [weak self] _ in self?.startLoading() })
            .eraseToAnyPublisher()

        let input = SelectSwapRouteViewModelInput(
            willAppear: willAppear,
            selection: selection.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)
        output.viewState
            .sink { [weak self, navigationItem, dataSource] state in
                navigationItem.title = state.title
                dataSource.apply(state.snapshot, animatingDifferences: false)
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
    private func makeDataSource() -> SelectSwapRouteViewModel.DataSource {
        SelectSwapRouteViewModel.DataSource(tableView: tableView) { tableView, indexPath, viewModel -> SelectableSwapRouteTableViewCell in
            let cell: SelectableSwapRouteTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}
