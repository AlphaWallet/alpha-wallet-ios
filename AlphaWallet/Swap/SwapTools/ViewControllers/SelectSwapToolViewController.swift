//
//  SelectSwapToolViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.09.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation
import StatefulViewController

final class SelectSwapToolViewController: UIViewController {
    private let viewModel: SelectSwapToolViewModel

    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(SelectableSwapToolTableViewCell.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.separatorInset = .zero
        tableView.delegate = self

        return tableView
    }()
    private lazy var dataSource: SelectSwapToolViewModel.DataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let disappear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<SelectSwapToolViewModel.SwapToolSelection, Never>()
    private var cancelable = Set<AnyCancellable>()

    init(viewModel: SelectSwapToolViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view)
        ])

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

    private func bind(viewModel: SelectSwapToolViewModel) {
        let willAppear = willAppear
            .handleEvents(receiveOutput: { [weak self] _ in self?.startLoading() })
            .eraseToAnyPublisher()

        let input = SelectSwapToolViewModelInput(
            willAppear: willAppear,
            disappear: disappear.eraseToAnyPublisher(),
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

extension SelectSwapToolViewController: PopNotifiable {
    func willPopViewController(animated: Bool) {
        disappear.send(())
    }

    func didPopViewController(animated: Bool) {
        //no-op
    }
}

extension SelectSwapToolViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension SelectSwapToolViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = dataSource.snapshot().itemIdentifiers[indexPath.row]
        selection.send(item.isSelected ? .deselect(indexPath) : .select(indexPath))
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNormalMagnitude
    }
}

extension SelectSwapToolViewController {
    private func makeDataSource() -> SelectSwapToolViewModel.DataSource {
        SelectSwapToolViewModel.DataSource(tableView: tableView) { tableView, indexPath, viewModel -> SelectableSwapToolTableViewCell in
            let cell: SelectableSwapToolTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}
