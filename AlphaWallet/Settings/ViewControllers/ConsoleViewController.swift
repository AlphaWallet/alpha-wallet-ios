// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import AlphaWalletFoundation
import Combine
import StatefulViewController

protocol ConsoleViewControllerDelegate: AnyObject {
    func didClose(in viewController: ConsoleViewController)
}

class ConsoleViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(UITableViewCell.self)
        tableView.delegate = self

        return tableView
    }()
    private let viewModel: ConsoleViewModel
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource: ConsoleViewModel.DataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()

    weak var delegate: ConsoleViewControllerDelegate?

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])
        
        emptyView = EmptyView.consoleEmptyView()
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

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func bind(viewModel: ConsoleViewModel) {
        let input = ConsoleViewModelInput(willAppear: willAppear.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource, navigationItem, weak self] viewState in
                navigationItem.title = viewState.title
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
                self?.endLoading(animated: false)
            }.store(in: &cancelable)
    }
}

extension ConsoleViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

fileprivate extension ConsoleViewController {
    private func makeDataSource() -> ConsoleViewModel.DataSource {
        return ConsoleViewModel.DataSource(tableView: tableView, cellProvider: { tableView, indexPath, message in
            let cell: UITableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.text = message

            return cell
        })
    }
}

extension ConsoleViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension ConsoleViewController: UITableViewDelegate {
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
