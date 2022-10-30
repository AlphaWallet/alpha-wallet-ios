// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol LockCreatePasscodeViewControllerDelegate: NSObjectProtocol {
    func didSetPassword(in viewController: LockCreatePasscodeViewController)
    func didClose(in viewController: LockCreatePasscodeViewController)
}

class LockCreatePasscodeViewController: LockPasscodeViewController {
    private let viewModel: LockCreatePasscodeViewModel

    weak var delegate: LockCreatePasscodeViewControllerDelegate?

    init(lockCreatePasscodeViewModel: LockCreatePasscodeViewModel) {
        self.viewModel = lockCreatePasscodeViewModel
        super.init(model: lockCreatePasscodeViewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = viewModel.title
        lockView.lockTitle.text = viewModel.initialLabelText
    }

    override func enteredPasscode(_ passcode: String) {
        super.enteredPasscode(passcode)

        if let first = viewModel.firstPasscode {
            if passcode == first {
                viewModel.set(passcode: passcode)
                hideKeyboard()
                delegate?.didSetPassword(in: self)
            } else {
                lockView.shake()
                viewModel.set(firstPasscode: nil)
                showFirstPasscodeView()
            }
        } else {
            viewModel.set(firstPasscode: passcode)
            showConfirmPasscodeView()
        }
    }

    private func showFirstPasscodeView() {
        lockView.lockTitle.text = viewModel.initialLabelText
    }

    private func showConfirmPasscodeView() {
        lockView.lockTitle.text = viewModel.confirmLabelText
    }
}

extension LockCreatePasscodeViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}
