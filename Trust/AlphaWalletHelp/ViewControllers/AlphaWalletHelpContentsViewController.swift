// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AlphaWalletHelpContentsViewController: StaticHTMLViewController {
    let banner = AlphaWalletContactUsBannerView()

    override init() {
        super.init()

        banner.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: footer.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: footer.trailingAnchor),
            banner.topAnchor.constraint(equalTo: footer.topAnchor),
            banner.bottomAnchor.constraint(equalTo: footer.bottomAnchor),
        ])

        configure()
    }

    func configure() {
        banner.configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func footerHeight() -> CGFloat {
        return banner.bannerHeight
    }
}

