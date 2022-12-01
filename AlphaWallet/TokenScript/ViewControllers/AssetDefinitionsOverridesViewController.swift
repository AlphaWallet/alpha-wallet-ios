// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import StatefulViewController
import Combine

protocol AssetDefinitionsOverridesViewControllerDelegate: AnyObject {
    func didTapShare(file: URL, in viewController: AssetDefinitionsOverridesViewController)
    func didClose(in viewController: AssetDefinitionsOverridesViewController)
}

class AssetDefinitionsOverridesViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.grouped
        tableView.register(AssetDefinitionsOverridesViewCell.self)
        tableView.delegate = self

        return tableView
    }()

    private let viewModel: AssetDefinitionsOverridesViewModel
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let deletion = PassthroughSubject<URL, Never>()

    weak var delegate: AssetDefinitionsOverridesViewControllerDelegate?

    init(viewModel: AssetDefinitionsOverridesViewModel) {
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

    private func bind(viewModel: AssetDefinitionsOverridesViewModel) {
        let input = AssetDefinitionsOverridesViewModelInput(
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

extension AssetDefinitionsOverridesViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

fileprivate extension AssetDefinitionsOverridesViewController {
    private func makeDataSource() -> AssetDefinitionsOverridesViewModel.DataSource {
        return AssetDefinitionsOverridesViewModel.DataSource(tableView: tableView, cellProvider: { tableView, indexPath, viewModel in
            let cell: AssetDefinitionsOverridesViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        })
    }
}

extension AssetDefinitionsOverridesViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension AssetDefinitionsOverridesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        deletion.send(dataSource.item(at: indexPath).url)
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
