// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class HelpViewController: UIViewController {
    let tableView = UITableView()
    let banner = ContactUsBannerView()
    let rows: [(title: String, controller: UIViewController)] = [
        (title: R.string.localizable.aHelpContentsWhatIsETH(), controller: WhatIsEthereumInfoViewController()),
        (title: R.string.localizable.aHelpContentsWhyETH(), controller: WhyUseEthereumInfoViewController()),
        (title: R.string.localizable.aHelpContentsHowDoIGetMyMoney(), controller: HowDoIGetMyMoneyInfoViewController()),
        (title: R.string.localizable.aHelpContentsWhatIsSeedPhrase(), controller: WhatIsASeedPhraseInfoViewController()),
        (title: R.string.localizable.aHelpContentsHowDoITransferETHIntoMyWallet(),controller: HowDoITransferETHIntoMyWalletInfoViewController()),
        (title: R.string.localizable.aHelpContentsPrivacyPolicy(),controller: PrivacyPolicyViewController()),
        (title: R.string.localizable.aHelpContentsTermsOfService(),controller: TermsOfServiceViewController()),
    ]

    init() {
        super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.aHelpNavigationTitle()

        view.backgroundColor = Colors.appBackground

        tableView.register(HelpViewCell.self, forCellReuseIdentifier: HelpViewCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appBackground
        view.addSubview(tableView)

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
