// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class LockCreatePasscodeViewController: LockPasscodeViewController {
	private let lockCreatePasscodeViewModel: LockCreatePasscodeViewModel

    init(lockCreatePasscodeViewModel: LockCreatePasscodeViewModel) {
        self.lockCreatePasscodeViewModel = lockCreatePasscodeViewModel
        super.init(model: lockCreatePasscodeViewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

	override func viewDidLoad() {
		super.viewDidLoad()
		title = lockCreatePasscodeViewModel.title
		lockView.lockTitle.text = lockCreatePasscodeViewModel.initialLabelText
	}

	override func enteredPasscode(_ passcode: String) {
		super.enteredPasscode(passcode)
        if let first = lockCreatePasscodeViewModel.firstPasscode {
			if passcode == first {
                lockCreatePasscodeViewModel.lock.setPasscode(passcode: passcode)
				finish(withResult: true, animated: true)
			} else {
				lockView.shake()
                lockCreatePasscodeViewModel.set(firstPasscode: nil)
				showFirstPasscodeView()
			}
		} else {
            lockCreatePasscodeViewModel.set(firstPasscode: passcode)
			showConfirmPasscodeView()
		}
	}

	private func showFirstPasscodeView() {
		lockView.lockTitle.text = lockCreatePasscodeViewModel.initialLabelText
	}

	private func showConfirmPasscodeView() {
		lockView.lockTitle.text = lockCreatePasscodeViewModel.confirmLabelText
	}
}
