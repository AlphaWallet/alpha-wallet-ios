//
//  ChangeCurrencyViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.06.2020.
//

import UIKit
import AlphaWalletFoundation
import Combine

protocol ChangeCurrencyViewControllerDelegate: AnyObject {
    func didClose(in viewController: ChangeCurrencyViewController)
    func controller(_ viewController: ChangeCurrencyViewController, didSelectCurrency currency: Currency)
}

class ChangeCurrencyViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.delegate = self
        tableView.separatorInset = .zero
        tableView.register(CurrencyTableViewCell.self)

        return tableView
    }()
    private let viewModel: ChangeCurrencyViewModel
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource: ChangeCurrencyViewModel.DataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<IndexPath, Never>()

    weak var delegate: ChangeCurrencyViewControllerDelegate?

    init(viewModel: ChangeCurrencyViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        bind(viewModel: viewModel)
    }

    private func bind(viewModel: ChangeCurrencyViewModel) {
        let input = ChangeCurrencyViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            selection: selection.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource, navigationItem] viewState in
                navigationItem.title = viewState.title
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
            }.store(in: &cancelable)

        output.selectedCurrency
            .sink(receiveValue: { self.delegate?.controller(self, didSelectCurrency: $0) })
            .store(in: &cancelable)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

}

extension ChangeCurrencyViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension ChangeCurrencyViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selection.send(indexPath)
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

fileprivate extension ChangeCurrencyViewController {
    func makeDataSource() -> ChangeCurrencyViewModel.DataSource {
        return ChangeCurrencyViewModel.DataSource(tableView: tableView, cellProvider: { tableView, indexPath, viewModel in
            let cell: CurrencyTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        })
    }
}
