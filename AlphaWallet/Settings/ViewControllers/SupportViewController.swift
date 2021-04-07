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
    private let analyticsCoordinator: AnalyticsCoordinator
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

    init(analyticsCoordinator: AnalyticsCoordinator) {
        self.analyticsCoordinator = analyticsCoordinator
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch viewModel.rows[indexPath.row] {
        case .faq:
            logAccessFaq()
            openURL(.faq)
        case .telegramPublic:
            logAccessTelegramPublic()
            openURL(.telegramPublic)
        case .telegramCustomer:
            logAccessTelegramCustomerSupport()
            openURL(.telegramCustomer)
        case .twitter:
            logAccessTwitter()
            openURL(.twitter)
        case .reddit:
            logAccessReddit()
            openURL(.reddit)
        case .facebook:
            logAccessFacebook()
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

// MARK: Analytics
extension SupportViewController {
    private func logAccessFaq() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.faq)
    }

    private func logAccessTelegramPublic() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.telegramPublic)
    }

    private func logAccessTelegramCustomerSupport() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.telegramCustomerSupport)
    }

    private func logAccessTwitter() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.twitter)
    }

    private func logAccessReddit() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.reddit)
    }

    private func logAccessFacebook() {
        analyticsCoordinator.log(navigation: Analytics.Navigation.facebook)
    }
}