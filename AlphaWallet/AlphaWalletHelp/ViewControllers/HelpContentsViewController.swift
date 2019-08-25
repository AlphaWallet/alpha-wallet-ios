// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class HelpContentsViewController: StaticHTMLViewController {
    private let banner = ContactUsBannerView()

    override var footerHeight: CGFloat {
        return ContactUsBannerView.bannerHeight
    }

    override init(delegate: StaticHTMLViewControllerDelegate?) {
        super.init(delegate: delegate)

        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.anchorsConstraint(to: footer)
        ])

        configure()
    }

    func configure() {
        banner.configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension HelpContentsViewController: ContactUsBannerViewDelegate {
    func present(_ viewController: UIViewController, for view: ContactUsBannerView) {
        present(viewController, animated: true, completion: nil)
    }
}

