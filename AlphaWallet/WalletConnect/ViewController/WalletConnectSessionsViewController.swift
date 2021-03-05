// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol WalletConnectSessionsViewControllerDelegate: class {
    func didSelect(session: WalletConnectSession, in viewController: WalletConnectSessionsViewController)
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
    private var sessionsValue: [WalletConnectSession] {
        return sessionsToURLServersMap.value?.sessions ?? []
    }
    private var urlToServer: [WalletConnectURL: RPCServer] {
        return sessionsToURLServersMap.value?.urlToServer ?? [:]
    }

    private let sessionsToURLServersMap: Subscribable<SessionsToURLServersMap>
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.register(WalletConnectSessionCell.self)
        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.separatorInset = .zero
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    weak var delegate: WalletConnectSessionsViewControllerDelegate?

    private lazy var spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .gray)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.hidesWhenStopped = true
        view.tintColor = .red
        return view
    }()

    init(sessionsToURLServersMap: Subscribable<SessionsToURLServersMap>) {
        self.sessionsToURLServersMap = sessionsToURLServersMap
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        view.addSubview(spinner)

        sessionsToURLServersMap.subscribe { [weak self] _ in
            self?.tableView.reloadData()
        }

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view),
            spinner.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem.backBarButton(self, selector: #selector(closeButtonSelected))
        navigationItem.rightBarButtonItem = UIBarButtonItem.qrCodeBarButton(self, selector: #selector(qrCodeButtonSelected))
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never
        hidesBottomBarWhenPushed = true
    }

    func configure(state: State) {
        title = R.string.localizable.walletConnectTitle()
        set(state: state)
    }

    func set(state: State) {
        switch state {
        case .loading:
            spinner.startAnimating()
        case .sessions:
            spinner.stopAnimating()
        }
    }

    @objc private func qrCodeButtonSelected(_ sender: UIBarButtonItem) {
        guard let delegate = self.delegate else { return }

        delegate.qrCodeSelected(in: self)
    }

    @objc private func closeButtonSelected(_ sender: UIBarButtonItem) {
        guard let delegate = self.delegate else { return }

        delegate.didClose(in: self)
    }
}

extension WalletConnectSessionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        delegate?.didSelect(session: sessionsValue[indexPath.row], in: self)
    }
}

extension WalletConnectSessionsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: WalletConnectSessionCell = tableView.dequeueReusableCell(for: indexPath)

        let session = sessionsValue[indexPath.row]
        if let server = urlToServer[session.url] {
            let viewModel = WalletConnectSessionCellViewModel(session: session, server: server)
            cell.configure(viewModel: viewModel)
        } else {
            //Should be impossible
        }
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessionsValue.count
    }
}
