//
//  SupportViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2020.
//

import UIKit

protocol SupportViewControllerDelegate: class, CanOpenURL {

}

class SupportViewController: UIViewController {

    private lazy var viewModel: SupportViewModel = SupportViewModel()
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(SettingViewHeader.self, forHeaderFooterViewReuseIdentifier: SettingViewHeader.reusableIdentifier)
        tableView.register(SettingTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background

        return tableView
    }()
    weak var delegate: SupportViewControllerDelegate?

    override func loadView() {
        view = tableView
    }

    init() {
        super.init(nibName: nil, bundle: nil)

        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = viewModel.title
        view.backgroundColor = Screen.Setting.Color.background
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = GroupedTable.Color.background
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }
}

extension SupportViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SettingTableViewCell = tableView.dequeueReusableCell(for: indexPath) 
        cell.configure(viewModel: viewModel.cellViewModel(indexPath: indexPath))

        return cell
    }
}

extension SupportViewController: HelpViewControllerDelegate {

}

extension SupportViewController: CanOpenURL {

    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, server: RPCServer, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}

extension SupportViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.01
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch viewModel.rows[indexPath.row] {
        case .faq:
            let viewController = HelpViewController(delegate: self)
            viewController.navigationItem.largeTitleDisplayMode = .never
            viewController.hidesBottomBarWhenPushed = true

            navigationController?.pushViewController(viewController, animated: true)
        case .telegramPublic:
            openURL(.telegramPublic)
        case .telegramCustomer:
            openURL(.telegramCustomer)
        case .twitter:
            openURL(.twitter)
        case .reddit:
            openURL(.reddit)
        case .facebook:
            openURL(.facebook)
        case .blog:
            break
        }
    }

    private func openURL(_ provider: URLServiceProvider) {
        if let localURL = provider.localURL, UIApplication.shared.canOpenURL(localURL) {
            UIApplication.shared.open(localURL, options: [:], completionHandler: .none)
        } else {
            delegate?.didPressOpenWebPage(provider.remoteURL, in: self)
        }
    }
}
