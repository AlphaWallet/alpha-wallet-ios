// Copyright © 2020 Stormbird PTE. LTD.

import UIKit
import StatefulViewController
import AlphaWalletAddress

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

class WalletConnectSessionsViewController: UIViewController {
    private var sessions: [AlphaWallet.WalletConnect.Session] {
        return sessionsSubscribable.value ?? []
    }

    private let sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]>
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(WalletConnectSessionCell.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.delegate = self
        tableView.dataSource = self
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
        view.tintColor = .red

        return view
    }()
    private var state: State = .sessions

    init(sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]>) {
        self.sessionsSubscribable = sessionsSubscribable
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = GroupedTable.Color.background

        view.addSubview(roundedBackground)
        roundedBackground.addSubview(tableView)
        roundedBackground.addSubview(spinner)

        sessionsSubscribable.subscribe { [weak self] _ in
            self?.tableView.reloadData()
            self?.endLoading()
        }

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

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

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never
        hidesBottomBarWhenPushed = true

        if let host = emptyView {
            spinner.bringSubviewToFront(host)
        }
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
        
        self.endLoading()
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
            return !sessions.isEmpty
        case .loading:
            return true
        }
    }
}

extension WalletConnectSessionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        delegate?.didSessionSelected(session: sessions[indexPath.row], in: self)
    }
}

extension WalletConnectSessionsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.walletConnectSessionDisconnect()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] (_, _, completionHandler) in
            guard let strongSelf = self else { return }
            let session = strongSelf.sessions[indexPath.row]
            strongSelf.delegate?.didDisconnectSelected(session: session, in: strongSelf)

            completionHandler(true)
        }

        hideAction.backgroundColor = R.color.danger()
        hideAction.image = R.image.hideToken()
        let configuration = UISwipeActionsConfiguration(actions: [hideAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: WalletConnectSessionCell = tableView.dequeueReusableCell(for: indexPath)

        let viewModel = WalletConnectSessionCellViewModel(session: sessions[indexPath.row])
        cell.configure(viewModel: viewModel)

        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
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
