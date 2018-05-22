// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class HelpContentsViewController: StaticHTMLViewController {
    let banner = ContactUsBannerView()

    override init() {
        super.init()

        banner.delegate = self
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

extension HelpContentsViewController: ContactUsBannerViewDelegate {
    func present(_ viewController: UIViewController, for view: ContactUsBannerView) {
        present(viewController, animated: true, completion: nil)
    }
}

