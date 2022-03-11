// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import StatefulViewController
import AlphaWalletAddress
import Combine

protocol WalletConnectSessionsViewControllerDelegate: AnyObject {
    func didDisconnectSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController)
    func didSessionSelected(session: AlphaWallet.WalletConnect.Session, in viewController: WalletConnectSessionsViewController)
    func qrCodeSelected(in viewController: WalletConnectSessionsViewController)
    func didClose(in viewController: WalletConnectSessionsViewController)
}

extension WalletConnectSessionsViewController {
    enum State {
        case sessions
        case loading
    }
}

class WalletConnectSessionsViewModel {
    enum Section: Int, Hashable, CaseIterable {
        case sessions
    }
}

private class WalletConnectSessionsDiffableDataSource: UITableViewDiffableDataSource<WalletConnectSessionsViewModel.Section, AlphaWallet.WalletConnect.Session> {}

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

    weak var delegate: WalletConnectSessionsViewControllerDelegate?
    private let roundedBackground = RoundedBackground()
    
    private lazy var spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.hidesWhenStopped = true

        return view
    }()
    private var state: State = .sessions
    private let provider: WalletConnectServerProviderType
    private var cancelable = Set<AnyCancellable>()
    private var dataSource: WalletConnectSessionsDiffableDataSource!

    init(provider: WalletConnectServerProviderType) {
        self.provider = provider
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

    private func invalidateDataSource(animatingDifferences: Bool = false, session: [AlphaWallet.WalletConnect.Session]) {
        var snapshot = NSDiffableDataSourceSnapshot<WalletConnectSessionsViewModel.Section, AlphaWallet.WalletConnect.Session>()
        snapshot.appendSections([.sessions])
        snapshot.appendItems(session)

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    private func configureDataSource() {
        dataSource = WalletConnectSessionsDiffableDataSource(tableView: tableView, cellProvider: { tableView, indexPath, session in
            let cell: WalletConnectSessionCell = tableView.dequeueReusableCell(for: indexPath)

            let viewModel = WalletConnectSessionCellViewModel(session: session)
            cell.configure(viewModel: viewModel)

            return cell
        })

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
        provider.sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                self?.invalidateDataSource(session: sessions)
                self?.endLoading()
            }.store(in: &cancelable)
    }

    func configure(state: State) {
        title = R.string.localizable.walletConnectTitle()
        set(state: state)
    }

    func set(state: State) {
        self.state = state
        switch state {
        case .loading:
            spinner.startAnimating()
        case .sessions:
            spinner.stopAnimating()
        }
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
        switch state {
        case .sessions:
            return dataSource.snapshot().numberOfItems != 0
        case .loading:
            return true
        }
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
