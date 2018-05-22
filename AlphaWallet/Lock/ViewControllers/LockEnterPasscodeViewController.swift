// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import LocalAuthentication

class LockEnterPasscodeViewController: LockPasscodeViewController {
	private lazy var lockEnterPasscodeViewModel: LockEnterPasscodeViewModel? = {
		return self.model as? LockEnterPasscodeViewModel
	}()
	var unlockWithResult: ((_ success: Bool, _ bioUnlock: Bool) -> Void)?
	private var context: LAContext!
	override func viewDidLoad() {
		super.viewDidLoad()
		self.lockView.lockTitle.text = lockEnterPasscodeViewModel?.initialLabelText
	}
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		//If max attempt limit is reached we should valdiate if one minute gone.
		if lock.incorrectMaxAttemptTimeIsSet() {
			self.lockView.lockTitle.text = lockEnterPasscodeViewModel?.tryAfterOneMinute
			maxAttemptTimerValidation()
		}
	}
	func showBioMerickAuth() {
		self.context = LAContext()
		self.touchValidation()
	}
	override func enteredPasscode(_ passcode: String) {
		super.enteredPasscode(passcode)
		if lock.isPasscodeValid(passcode: passcode) {
			lock.resetPasscodeAttemptHistory()
			lock.removeIncorrectMaxAttemptTime()
			self.lockView.lockTitle.text = lockEnterPasscodeViewModel?.initialLabelText
			unlock(withResult: true, bioUnlock: false)
		} else {
			let numberOfAttempts = self.lock.numberOfAttempts()
			let passcodeAttemptLimit = model.passcodeAttemptLimit()
			let text = R.string.localizable.lockEnterPasscodeViewModelIncorrectPasscode(passcodeAttemptLimit - numberOfAttempts)
			lockView.lockTitle.text = text
			lockView.shake()
			if numberOfAttempts >= passcodeAttemptLimit {
				exceededLimit()
				return
			}
			self.lock.recordIncorrectPasscodeAttempt()
		}
	}
	private func exceededLimit() {
		self.lockView.lockTitle.text = lockEnterPasscodeViewModel?.tryAfterOneMinute
		lock.recordIncorrectMaxAttemptTime()
		self.hideKeyboard()
	}
	private func maxAttemptTimerValidation() {
		let now = Date()
		let maxAttemptTimer = lock.recordedMaxAttemptTime()
		let interval = now.timeIntervalSince(maxAttemptTimer)
		//if interval is greater or equal 60 seconds we give 1 attempt.
		if interval >= 60 {
			self.lockView.lockTitle.text = lockEnterPasscodeViewModel?.initialLabelText
			self.showKeyboard()
		}
	}
	private func unlock(withResult success: Bool, bioUnlock: Bool) {
		self.view.endEditing(true)
		if let unlock = unlockWithResult {
			unlock(success, bioUnlock)
		}
	}
	private func canEvaluatePolicy() -> Bool {
		return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
	}
	private func touchValidation() {
		guard canEvaluatePolicy(), let reason = lockEnterPasscodeViewModel?.loginReason else {
			return
		}
		self.hideKeyboard()
		context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, _ in
			DispatchQueue.main.async {
				if success {
					self?.lock.resetPasscodeAttemptHistory()
					self?.lock.removeIncorrectMaxAttemptTime()
					self?.lockView.lockTitle.text = self?.lockEnterPasscodeViewModel?.initialLabelText
					self?.unlock(withResult: true, bioUnlock: true)
				} else {
					self?.showKeyboard()
				}
			}
		}
	}
}
