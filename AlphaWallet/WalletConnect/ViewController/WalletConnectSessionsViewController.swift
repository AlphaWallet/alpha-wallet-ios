// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import StatefulViewController
import AlphaWalletAddress
import Combine
import AlphaWalletFoundation

protocol WalletConnectSessionsViewControllerDelegate: AnyObject {
    func didDisconnectSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController)
    func didSessionSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController)
    func qrCodeSelected(in viewController: WalletConnectSessionsViewController)
    func didClose(in viewController: WalletConnectSessionsViewController)
}

class WalletConnectSessionsViewController: UIViewController {

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(WalletConnectSessionCell.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = GroupedTable.Color.background

        return tableView
    }()

    private let roundedBackground = RoundedBackground()
    
    private lazy var spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.hidesWhenStopped = true

        return view
    }()
    private var cancelable = Set<AnyCancellable>()
    private lazy var dataSource = WalletConnectSessionsDiffableDataSource(tableView: tableView, cellProvider: { tableView, indexPath, session in
        let cell: WalletConnectSessionCell = tableView.dequeueReusableCell(for: indexPath)

        let viewModel = WalletConnectSessionCellViewModel(session: session)
        cell.configure(viewModel: viewModel)

        return cell
    })

    let viewModel: WalletConnectSessionsViewModel
    weak var delegate: WalletConnectSessionsViewControllerDelegate?

    init(viewModel: WalletConnectSessionsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = GroupedTable.Color.background

        view.addSubview(roundedBackground)
        roundedBackground.addSubview(tableView)
        roundedBackground.addSubview(spinner)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraintSafeArea(to: roundedBackground),
            spinner.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(closeButtonSelected))
        navigationItem.rightBarButtonItem = UIBarButtonItem.qrCodeBarButton(self, selector: #selector(qrCodeButtonSelected))

        emptyView = EmptyView.walletSessionEmptyView(completion: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.qrCodeSelected(in: strongSelf)
        })
    }

    private func configureDataSource() {
        tableView.delegate = self
        tableView.dataSource = dataSource
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never
        hidesBottomBarWhenPushed = true

        if let host = emptyView {
            spinner.bringSubviewToFront(host)
        }

        configureDataSource()
        configure(viewModel: viewModel)
    }

    func configure(viewModel: WalletConnectSessionsViewModel) {
        title = viewModel.natigationTitle

        viewModel.stateSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.endLoading()

                switch state {
                case .waitingForSessionConnection:
                    self?.spinner.startAnimating()
                case .sessions:
                    self?.spinner.stopAnimating()
                }
            }.store(in: &cancelable)

        viewModel.sessionsSnapshot
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
                self?.endLoading()
            }.store(in: &cancelable)
    }

    @objc private func qrCodeButtonSelected(_ sender: UIBarButtonItem) {
        delegate?.qrCodeSelected(in: self)
    }

    @objc private func closeButtonSelected(_ sender: UIBarButtonItem) {
        delegate?.didClose(in: self)
    }
}

extension WalletConnectSessionsViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.hasAnyContent(dataSource)
    }
}

extension WalletConnectSessionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let session = dataSource.itemIdentifier(for: indexPath) else { return }

        delegate?.didSessionSelected(session: session, in: self)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.walletConnectSessionDisconnect()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] (_, _, completionHandler) in
            guard let strongSelf = self else { return }
            guard let session = strongSelf.dataSource.itemIdentifier(for: indexPath) else { return }

            strongSelf.delegate?.didDisconnectSelected(session: session, in: strongSelf)

            completionHandler(true)
        }

        hideAction.backgroundColor = R.color.danger()
        hideAction.image = R.image.hideToken()
        let configuration = UISwipeActionsConfiguration(actions: [hideAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
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
