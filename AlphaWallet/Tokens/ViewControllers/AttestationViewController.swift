// Copyright © 2023 Stormbird PTE. LTD.

import UIKit
import AlphaWalletAttestation
import AlphaWalletFoundation

class AttestationViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableView.register(Cell.self)

        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.separatorInset = .zero
        tableView.contentInsetAdjustmentBehavior = .never
        return tableView
    }()
    private let attestation: Attestation

    init(attestation: Attestation) {
        self.attestation = attestation

        super.init(nibName: nil, bundle: nil)

        title = "Attestation"
        view.backgroundColor = Configuration.Color.Semantic.searchBarBackground

        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

fileprivate class Cell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension AttestationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return attestation.data.count + 4
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: Cell = tableView.dequeueReusableCell(for: indexPath)
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = R.string.localizable.transactionNetworkLabelTitle()
            cell.detailTextLabel?.text = RPCServer(chainID: attestation.chainId).name
        case 1:
            cell.textLabel?.text = R.string.localizable.contractAddress()
            cell.detailTextLabel?.text = attestation.verifyingContract?.eip55String
        case 2:
            cell.textLabel?.text = "Valid from"
            cell.detailTextLabel?.text = String(describing: attestation.time)
        case 3:
            cell.textLabel?.text = "Valid until"
            cell.detailTextLabel?.text = String(describing: attestation.expirationTime)
        default:
            let i = indexPath.row - 4
            let pair = attestation.data[i]
            cell.textLabel?.text = pair.type.name
            cell.detailTextLabel?.text = pair.value.stringValue
        }
        return cell
    }
}

extension AttestationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
