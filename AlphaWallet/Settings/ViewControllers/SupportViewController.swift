//
//  SupportViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.06.2020.
//

import UIKit
import AlphaWalletFoundation

protocol SupportViewControllerDelegate: class, CanOpenURL {

}

class SupportViewController: UIViewController {
    private let analytics: AnalyticsLogger
    private lazy var viewModel: SupportViewModel = SupportViewModel()
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.tableFooterView = UIView.tableFooterToRemoveEmptyCellSeparators()
        tableView.register(SettingTableViewCell.self)
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        return tableView
    }()
    private let roundedBackground = RoundedBackground()
    weak var delegate: SupportViewControllerDelegate?
    private let resolver = ContactUsEmailResolver()

    init(analytics: AnalyticsLogger) {
        self.analytics = analytics
        super.init(nibName: nil, bundle: nil)

        roundedBackground.backgroundColor = GroupedTable.Color.background

        view.addSubview(roundedBackground)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = viewModel.title
        navigationItem.largeTitleDisplayMode = .never
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
        case .discord:
            logAccessDiscord()
            openURL(.discord)
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
        case .github:
            logAccessGithub()
            openURL(.github)
        case .email:
            let attachments = Features.default.isAvailable(.isAttachingLogFilesToSupportEmailEnabled) ? DDLogger.logFilesAttachments : []
            resolver.present(from: self, attachments: attachments)
        }
    }

    private func openURL(_ provider: URLServiceProvider) {
        if let deepLinkURL = provider.deepLinkURL, UIApplication.shared.canOpenURL(deepLinkURL) {
            UIApplication.shared.open(deepLinkURL, options: [:], completionHandler: .none)
        } else {
            delegate?.didPressOpenWebPage(provider.remoteURL, in: self)
        }
    }
}

// MARK: Analytics
extension SupportViewController {
    private func logAccessFaq() {
        analytics.log(navigation: Analytics.Navigation.faq)
    }

    private func logAccessDiscord() {
        analytics.log(navigation: Analytics.Navigation.discord)
    }

    private func logAccessTelegramCustomerSupport() {
        analytics.log(navigation: Analytics.Navigation.telegramCustomerSupport)
    }

    private func logAccessTwitter() {
        analytics.log(navigation: Analytics.Navigation.twitter)
    }

    private func logAccessReddit() {
        analytics.log(navigation: Analytics.Navigation.reddit)
    }

    private func logAccessFacebook() {
        analytics.log(navigation: Analytics.Navigation.facebook)
    }

    private func logAccessGithub() {
        analytics.log(navigation: Analytics.Navigation.github)
    }
}
