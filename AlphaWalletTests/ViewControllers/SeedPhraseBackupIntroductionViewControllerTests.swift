//
//  SeedPhraseBackupIntroductionViewControllerTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 10.08.2020.
//

import XCTest
@testable import AlphaWallet

class SeedPhraseBackupIntroductionViewControllerTests: XCTestCase {

    func testContentHeightFits() throws {
        let controller = SeedPhraseBackupIntroductionViewController(account: .make())
        controller.configure()
        controller.view.layoutIfNeeded()

        XCTAssertFalse(controller.descriptionLabel2.overlaps(other: controller.buttonsBar, in: controller))
    }

}

private extension UIView {
    func overlaps(other view: UIView, in viewController: UIViewController) -> Bool {
        let frame = self.convert(self.bounds, to: viewController.view)
        let otherFrame = view.convert(view.bounds, to: viewController.view)
        return frame.intersects(otherFrame)
    }
}
