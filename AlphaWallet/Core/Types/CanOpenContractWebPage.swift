//Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol CanOpenURL {
    func didPressViewContractWebPage(forContract contract: String, in viewController: UIViewController)
    func didPressViewContractWebPage(_ url: URL, in viewController: UIViewController)
    func didPressOpenWebPage(_ url: URL, in viewController: UIViewController)
}
