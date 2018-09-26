// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol HelpViewControllerDelegate: class, CanOpenURL {
}

class HelpViewController: UIViewController {
    private let banner = ContactUsBannerView()
    private lazy var rows: [(title: String, controller: UIViewController)] = [
        (title: R.string.localizable.aHelpContentsWhatIsETH(), controller: WhatIsEthereumInfoViewController(delegate: self)),
        (title: R.string.localizable.aHelpContentsHowDoIGetMyMoney(), controller: HowDoIGetMyMoneyInfoViewController(delegate: self)),
        (title: R.string.localizable.aHelpContentsHowDoITransferETHIntoMyWallet(), controller: HowDoITransferETHIntoMyWalletInfoViewController(delegate: self)),
        (title: R.string.localizable.aHelpContentsPrivacyPolicy(), controller: PrivacyPolicyViewController(delegate: self)),
        (title: R.string.localizable.aHelpContentsTermsOfService(), controller: TermsOfServiceViewController(delegate: self)),
    ]
    private weak var delegate: HelpViewControllerDelegate?

    init(delegate: HelpViewControllerDelegate?) {
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.aHelpNavigationTitle()

        view.backgroundColor = Colors.appBackground

        let tableView = UITableView()
        tableView.register(HelpViewCell.self, forCellReuseIdentifier: HelpViewCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        view.addSubview(tableView)

        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: banner.topAnchor),

            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.heightAnchor.constraint(equalToConstant: banner.bannerHeight),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
        navigationController?.pushViewController(controller, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
}

extension HelpViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: HelpViewCell.identifier, for: indexPath) as! HelpViewCell
        cell.configure(text: rows[indexPath.row].title)
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
}

extension HelpViewController: ContactUsBannerViewDelegate {
    func present(_ viewController: UIViewController, for view: ContactUsBannerView) {
        present(viewController, animated: true, completion: nil)
    }
}

extension HelpViewController: StaticHTMLViewControllerDelegate {
}

extension HelpViewController: CanOpenURL {
    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(forContract: contract, in: viewController)
    }

    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressViewContractWebPage(url, in: viewController)
    }

    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController) {
        delegate?.didPressOpenWebPage(url, in: viewController)
    }
}
