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
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(SelectableSwapToolTableViewCell.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = GroupedTable.Color.background

        return tableView
    }()
    private lazy var dataSource: SelectSwapToolViewModel.ToolsDiffableDataSource = makeDataSource()
    private let appear = PassthroughSubject<Void, Never>()
    private let disappear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<SelectSwapToolViewModel.SwapToolSelection, Never>()
    private var cancelable = Set<AnyCancellable>()

    init(viewModel: SelectSwapToolViewModel) {
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

    private func bind(viewModel: SelectSwapToolViewModel) {
        let appear = appear
            .handleEvents(receiveOutput: { [weak self] _ in self?.startLoading() })
            .eraseToAnyPublisher()

        let input = SelectSwapToolViewModelInput(
            appear: appear,
            disappear: disappear.eraseToAnyPublisher(),
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

extension SelectSwapToolViewController: PopNotifiable {
    @objc func willPopViewController(animated: Bool) {
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
    private func makeDataSource() -> SelectSwapToolViewModel.ToolsDiffableDataSource {
        SelectSwapToolViewModel.ToolsDiffableDataSource(tableView: tableView) { tableView, indexPath, viewModel -> SelectableSwapToolTableViewCell in
            let cell: SelectableSwapToolTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}
