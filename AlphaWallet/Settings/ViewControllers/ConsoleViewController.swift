// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol ConsoleViewControllerDelegate: class {
    func didClose(in viewController: ConsoleViewController)
}

//TODO reload when the list of files (and hence list of messages change)
class ConsoleViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var messages = [String]()
    weak var delegate: ConsoleViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.aConsoleTitle()

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        view.backgroundColor = GroupedTable.Color.background

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(messages: [String]) {
        self.messages = messages
        tableView.reloadData()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            delegate?.didClose(in: self)
            return
        }
    }
}

extension ConsoleViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ConsoleViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = messages[indexPath.row]
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
}
