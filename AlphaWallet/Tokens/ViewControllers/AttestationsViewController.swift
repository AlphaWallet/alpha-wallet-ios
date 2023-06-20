// Copyright © 2023 Stormbird PTE. LTD.

import UIKit
import AlphaWalletAttestation
import AlphaWalletFoundation

protocol AttestationsViewControllerDelegate: AnyObject {
    func openAttestation(_ attestation: Attestation, fromViewController: AttestationsViewController)
}

//For development only
class AttestationsViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false

        tableView.register(AttestationViewCell.self)

        tableView.estimatedRowHeight = DataEntry.Metric.TableView.estimatedRowHeight
        tableView.separatorInset = .zero
        tableView.contentInsetAdjustmentBehavior = .never
        return tableView
    }()
    private let attestations: [Attestation]

    weak var delegate: AttestationsViewControllerDelegate?

    init(attestations: [Attestation]) {
        self.attestations = attestations

        super.init(nibName: nil, bundle: nil)

        title = "Attestations"
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

extension AttestationsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return attestations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let attestation = attestations[indexPath.row]
        let cell: AttestationViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: AttestationViewCellViewModel(attestation: attestation))
        return cell
    }
}

extension AttestationsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.openAttestation(attestations[indexPath.row], fromViewController: self)
    }
}
