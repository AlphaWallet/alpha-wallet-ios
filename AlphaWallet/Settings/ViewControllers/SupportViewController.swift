//
//  SupportViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2020.
//

import UIKit
import AlphaWalletFoundation
import Combine

protocol SupportViewControllerDelegate: AnyObject, CanOpenURL {
    func supportActionSelected(in viewController: SupportViewController, action: SupportViewModel.SupportAction)
    func didClose(in viewController: SupportViewController)
}

class SupportViewController: UIViewController {
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource: SupportViewModel.DataSource = makeDataSource()
    private let willAppear = PassthroughSubject<Void, Never>()
    private let selection = PassthroughSubject<IndexPath, Never>()
    private let viewModel: SupportViewModel

    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(SettingTableViewCell.self)
        tableView.delegate = self
        
        return tableView
    }()

    weak var delegate: SupportViewControllerDelegate?

    init(viewModel: SupportViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view)
        ])
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

    private func bind(viewModel: SupportViewModel) {
        let input = SupportViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            selection: selection.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource, navigationItem] viewState in
                navigationItem.title = viewState.title
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
            }.store(in: &cancelable)

        output.supportAction
            .sink { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.supportActionSelected(in: strongSelf, action: $0)
            }.store(in: &cancelable)
    }
}

fileprivate extension SupportViewController {
    private func makeDataSource() -> SupportViewModel.DataSource {
        return SupportViewModel.DataSource(tableView: tableView, cellProvider: { tableView, indexPath, viewModel in
            let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)
            cell.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

            return cell
        })
    }
}

extension SupportViewController: CanOpenURL {

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension SupportViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        selection.send(indexPath)
    }
}

extension SupportViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}
