// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol AssetDefinitionsOverridesViewControllerDelegate: AnyObject {
    func didDelete(overrideFileForContract file: URL, in viewController: AssetDefinitionsOverridesViewController)
    func didTapShare(file: URL, in viewController: AssetDefinitionsOverridesViewController)
}

class AssetDefinitionsOverridesViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.grouped
        tableView.register(AssetDefinitionsOverridesViewCell.self)
        tableView.delegate = self
        tableView.dataSource = self

        return tableView
    }()
    private let fileExtension: String
    private var overriddenURLs: [URL] = []
    private lazy var emptyView: UIView = {
        let emptyView = EmptyTableView(title: R.string.localizable.tokenscriptOverridesEmpty(), image: R.image.iconsIllustrationsSearchResults()!, heightAdjustment: 0.0)
        emptyView.isHidden = true
        return emptyView
    }()
    weak var delegate: AssetDefinitionsOverridesViewControllerDelegate?

    init(fileExtension: String) {
        self.fileExtension = fileExtension
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        tableView.addSubview(emptyView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view),
            emptyView.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    func configure(overriddenURLs urls: [URL]) {
        self.overriddenURLs = urls
        tableView.reloadData()
    }

}

extension AssetDefinitionsOverridesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            delegate?.didDelete(overrideFileForContract: overriddenURLs[indexPath.row], in: self)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.didTapShare(file: overriddenURLs[indexPath.row], in: self)
    }
}

extension AssetDefinitionsOverridesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: AssetDefinitionsOverridesViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(viewModel: .init(url: overriddenURLs[indexPath.row], fileExtension: fileExtension))
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = overriddenURLs.count
        handleEmptyTableAction(rows)
        return rows
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

    private func handleEmptyTableAction(_ rows: Int) {
        let newViewHiddenState = rows != 0
        guard emptyView.isHidden != newViewHiddenState else { return }
        emptyView.isHidden = newViewHiddenState
    }

}
