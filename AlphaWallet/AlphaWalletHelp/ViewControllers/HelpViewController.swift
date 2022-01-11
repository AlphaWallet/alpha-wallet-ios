// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol HelpViewControllerDelegate: class, CanOpenURL {
}

class HelpViewController: UIViewController {
    private let banner = ContactUsBannerView()
    private lazy var rows: [(title: String, controller: UIViewController)] = [
        (title: R.string.localizable.aHelpContentsWhatIsETH(preferredLanguages: Languages.preferred()), controller: WhatIsEthereumInfoViewController(delegate: self)),
        (title: R.string.localizable.aHelpContentsHowDoIGetMyMoney(preferredLanguages: Languages.preferred()), controller: HowDoIGetMyMoneyInfoViewController(delegate: self)),
        (title: R.string.localizable.aHelpContentsHowDoITransferETHIntoMyWallet(preferredLanguages: Languages.preferred()), controller: HowDoITransferETHIntoMyWalletInfoViewController(delegate: self)),
        (title: R.string.localizable.aHelpContentsPrivacyPolicy(preferredLanguages: Languages.preferred()), controller: PrivacyPolicyViewController(delegate: self)),
        (title: R.string.localizable.aHelpContentsTermsOfService(preferredLanguages: Languages.preferred()), controller: TermsOfServiceViewController(delegate: self)),
    ]
    private weak var delegate: HelpViewControllerDelegate?

    init(delegate: HelpViewControllerDelegate?) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.aHelpNavigationTitle(preferredLanguages: Languages.preferred())

        view.backgroundColor = Colors.appBackground

        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(HelpViewCell.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = GroupedTable.Color.background
        view.addSubview(tableView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        view.addSubview(footerBar)

        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        footerBar.addSubview(banner)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: banner.topAnchor),

            banner.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            banner.topAnchor.constraint(equalTo: footerBar.topAnchor),
            banner.heightAnchor.constraint(equalToConstant: ContactUsBannerView.bannerHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -ContactUsBannerView.bannerHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        banner.configure()
    }
}

extension HelpViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let controller = rows[indexPath.row].controller
        controller.hidesBottomBarWhenPushed = true
        controller.navigationItem.largeTitleDisplayMode = .never
        navigationController?.pushViewController(controller, animated: true)
    }
}

extension HelpViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: HelpViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.configure(text: rows[indexPath.row].title)
        return cell
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

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
}

extension HelpViewController: ContactUsBannerViewDelegate {
    func present(_ viewController: UIViewController, for view: ContactUsBannerView) {
        viewController.makePresentationFullScreenForiOS13Migration()
        present(viewController, animated: true)
    }
}

extension HelpViewController: StaticHTMLViewControllerDelegate {
}

extension HelpViewController: CanOpenURL {
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
