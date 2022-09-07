//
//  SwapOptionsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine

protocol SwapOptionsViewControllerDelegate: AnyObject {
    func didClose(in controller: SwapOptionsViewController)
}

class SwapOptionsViewController: UIViewController {
    private let viewModel: SwapOptionsViewModel

    private lazy var slippageView: SlippageView = {
        return SlippageView(viewModel: viewModel.slippageViewModel)
    }()

    private lazy var slippageHeaderView: SwapOptionsHeaderView = {
        let view = SwapOptionsHeaderView(viewModel: .init(title: "SLIPPAGE TOLERANCE"))
        return view
    }()

    private lazy var networkHeaderView: SwapOptionsHeaderView = {
        let view = SwapOptionsHeaderView(viewModel: .init(title: "Network"))
        return view
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(RPCDisplaySelectableTableViewCell.self)
        tableView.isEditing = false
        tableView.keyboardDismissMode = .onDrag

        return tableView
    }()

    private lazy var checker = KeyboardChecker(self, resetHeightDefaultValue: 0)
    private lazy var headerView = ConfirmationHeaderView(viewModel: .init(title: viewModel.navigationTitle))
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource: SwapOptionsViewModel.SessionsDiffableDataSource = makeDataSource()

    weak var delegate: SwapOptionsViewControllerDelegate?

    init(viewModel: SwapOptionsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let stackView = [
            headerView,
            .spacer(height: 30),
            slippageHeaderView.adjusted(),
            .spacer(height: 10),
            slippageView.adjusted(),
            .spacer(height: 30),
            networkHeaderView.adjusted(),
            .spacer(height: 10),
            tableView
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        let bottomConstraint = stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bottomConstraint
        ])

        checker.constraints = [bottomConstraint]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checker.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        checker.viewWillDisappear()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configureDataSource()
        headerView.configure(viewModel: .init(title: viewModel.navigationTitle))
        bind(viewModel: viewModel)
        headerView.closeButton.addTarget(self, action: #selector(closeDidSelect), for: .touchUpInside)
    } 

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func closeDidSelect(_ sender: UIButton) {
        delegate?.didClose(in: self)
    }

    private func bind(viewModel: SwapOptionsViewModel) {
        let output = viewModel.transform(input: .init())
        output.viewState
            .sink { [weak self] viewState in
                self?.dataSource.apply(viewState.sessions, animatingDifferences: false)
            }.store(in: &cancelable)

        //TODO: need to resolve error displaying, uncommenting this string causes displaying an error when screen in loading for first time
        // and for unavailable networks it shows error
        //output.errorString
        //    .receive(on: RunLoop.main)
        //    .sink { [weak self] error in
        //        self?.displayError(message: error)
        //    }.store(in: &cancelable)
    }
}

extension SwapOptionsViewController {
    private func makeDataSource() -> SwapOptionsViewModel.SessionsDiffableDataSource {
        SwapOptionsViewModel.SessionsDiffableDataSource(tableView: tableView) { tableView, indexPath, viewModel -> RPCDisplaySelectableTableViewCell? in
            let cell: RPCDisplaySelectableTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        }
    }

    private func configureDataSource() {
        tableView.delegate = self
        tableView.dataSource = dataSource
    }
}

extension SwapOptionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let session = viewModel.sessions[indexPath.row]
        viewModel.set(selectedServer: session.server)
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

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80.0
    }
}
