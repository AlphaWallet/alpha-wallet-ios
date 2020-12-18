// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

protocol WalletConnectSessionsViewControllerDelegate: class {
    func didSelect(session: WalletConnectSession, in viewController: WalletConnectSessionsViewController)
}

class WalletConnectSessionsViewController: UIViewController {
    private let sessions: Subscribable<[WalletConnectSession]>
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

    init(sessions: Subscribable<[WalletConnectSession]>) {
        self.sessions = sessions
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        sessions.subscribe { _ in
            self.tableView.reloadData()
        }

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    func configure() {
        navigationItem.largeTitleDisplayMode = .never
        hidesBottomBarWhenPushed = true
        title = R.string.localizable.walletConnectTitle()
    }
}

extension WalletConnectSessionsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let session = sessions.value?[indexPath.row] else { return }
        delegate?.didSelect(session: session, in: self)
    }
}

extension WalletConnectSessionsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(for: indexPath) as WalletConnectSessionCell
        guard let session = sessions.value?[indexPath.row] else { return cell }
        let viewModel = WalletConnectSessionCellViewModel(session: session)
        cell.configure(viewModel: viewModel)
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sessions.value?.count ?? 0
    }
}
