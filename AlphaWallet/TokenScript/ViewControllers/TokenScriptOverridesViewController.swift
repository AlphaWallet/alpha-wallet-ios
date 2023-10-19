// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import StatefulViewController
import Combine

protocol TokenScriptOverridesViewControllerDelegate: AnyObject {
    func didTapShare(file: URL, in viewController: TokenScriptOverridesViewController)
    func didClose(in viewController: TokenScriptOverridesViewController)
}

class TokenScriptOverridesViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(TokenScriptOverridesViewCell.self)
        tableView.delegate = self

        return tableView
    }()

    private let viewModel: TokenScriptOverridesViewModel
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let deletion = PassthroughSubject<URL, Never>()

    weak var delegate: TokenScriptOverridesViewControllerDelegate?

    init(viewModel: TokenScriptOverridesViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])

        emptyView = EmptyView.tokenscriptOverridesEmptyView()
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

    private func bind(viewModel: TokenScriptOverridesViewModel) {
        let input = TokenScriptOverridesViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            deletion: deletion.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource, navigationItem, weak self] viewState in
                navigationItem.title = viewState.title
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
                self?.endLoading(animated: false)
            }.store(in: &cancelable)
    }
}

extension TokenScriptOverridesViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

fileprivate extension TokenScriptOverridesViewController {
    private func makeDataSource() -> TokenScriptOverridesViewModel.DataSource {
        return TokenScriptOverridesViewModel.DataSource(tableView: tableView, cellProvider: { tableView, indexPath, viewModel in
            let cell: TokenScriptOverridesViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        })
    }
}

extension TokenScriptOverridesViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension TokenScriptOverridesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let hideAction = UIContextualAction(style: .destructive, title: R.string.localizable.delete()) { [deletion, dataSource] _, _, completionHandler in
            deletion.send(dataSource.item(at: indexPath).url)
            completionHandler(true)
        }

        hideAction.backgroundColor = Configuration.Color.Semantic.dangerBackground
        hideAction.image = R.image.hideToken()

        let configuration = UISwipeActionsConfiguration(actions: [hideAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.didTapShare(file: dataSource.item(at: indexPath).url, in: self)
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
