// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class LockEnterPasscodeViewController: LockPasscodeViewController {
    private let lockEnterPasscodeViewModel: LockEnterPasscodeViewModel

	var unlockWithResult: ((_ success: Bool, _ bioUnlock: Bool) -> Void)?

    init(lockEnterPasscodeViewModel: LockEnterPasscodeViewModel) {
        self.lockEnterPasscodeViewModel = lockEnterPasscodeViewModel
        super.init(model: lockEnterPasscodeViewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

	override func viewDidLoad() {
		super.viewDidLoad()
		lockView.lockTitle.text = lockEnterPasscodeViewModel.initialLabelText
	}
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		//If max attempt limit is reached we should validate if one minute gone.
        if lockEnterPasscodeViewModel.lock.isIncorrectMaxAttemptTimeSet {
			lockView.lockTitle.text = lockEnterPasscodeViewModel.tryAfterOneMinute
			maxAttemptTimerValidation()
		}
	}
	func showBioMetricAuth() {
        lockEnterPasscodeViewModel.invalidateContext()
		touchValidation()
	}
    
	override func enteredPasscode(_ passcode: String) {
		super.enteredPasscode(passcode)
        if lockEnterPasscodeViewModel.lock.isPasscodeValid(passcode: passcode) {
            lockEnterPasscodeViewModel.lock.resetPasscodeAttemptHistory()
            lockEnterPasscodeViewModel.lock.removeIncorrectMaxAttemptTime()
			lockView.lockTitle.text = lockEnterPasscodeViewModel.initialLabelText
			unlock(withResult: true, bioUnlock: false)
		} else {
            let numberOfAttempts = lockEnterPasscodeViewModel.lock.numberOfAttempts
			let passcodeAttemptLimit = lockEnterPasscodeViewModel.passcodeAttemptLimit
			let text = R.string.localizable.lockEnterPasscodeViewModelIncorrectPasscode(passcodeAttemptLimit - numberOfAttempts)
			lockView.lockTitle.text = text
			lockView.shake()
			if numberOfAttempts >= passcodeAttemptLimit {
				exceededLimit()
				return
			}
            lockEnterPasscodeViewModel.lock.recordIncorrectPasscodeAttempt()
		}
	}
	private func exceededLimit() {
		lockView.lockTitle.text = lockEnterPasscodeViewModel.tryAfterOneMinute
        lockEnterPasscodeViewModel.lock.recordIncorrectMaxAttemptTime()
		hideKeyboard()
	}
	private func maxAttemptTimerValidation() {
		let now = Date()
        let maxAttemptTimer = lockEnterPasscodeViewModel.lock.recordedMaxAttemptTime
		let interval = now.timeIntervalSince(maxAttemptTimer)
		//if interval is greater or equal 60 seconds we give 1 attempt.
		if interval >= 60 {
			lockView.lockTitle.text = lockEnterPasscodeViewModel.initialLabelText
			showKeyboard()
		}
	}
	private func unlock(withResult success: Bool, bioUnlock: Bool) {
		view.endEditing(true)
		if let unlock = unlockWithResult {
			unlock(success, bioUnlock)
		}
	}

	private func touchValidation() {
        guard lockEnterPasscodeViewModel.canEvaluatePolicy else { return }
		hideKeyboard()
		lockEnterPasscodeViewModel.evaluatePolicy() { [weak self] success in
            if success {
                self?.lockEnterPasscodeViewModel.lock.resetPasscodeAttemptHistory()
                self?.lockEnterPasscodeViewModel.lock.removeIncorrectMaxAttemptTime()
                self?.lockView.lockTitle.text = self?.lockEnterPasscodeViewModel.initialLabelText
                self?.unlock(withResult: true, bioUnlock: true)
            } else {
                self?.showKeyboard()
            }
		}
	}
}
