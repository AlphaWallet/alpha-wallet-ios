// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class LockPasscodeViewController: UIViewController {
	var willFinishWithResult: ((_ success: Bool) -> Void)?
	let model: LockViewModel
	var lockView: LockView!
	let lock = Lock()
	private var invisiblePasscodeField = UITextField()
	private var shouldIgnoreTextFieldDelegateCalls = false
	init(model: LockViewModel) {
		self.model = model
		super.init(nibName: nil, bundle: nil)
	}
	override func viewDidLoad() {
		self.navigationItem.hidesBackButton = true
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
		self.view.backgroundColor = Colors.appBackground
		self.configureInvisiblePasscodeField()
		self.configureNavigationItems()
		self.configureLockView()
	}
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if !invisiblePasscodeField.isFirstResponder && !lock.isIncorrectMaxAttemptTimeSet {
			invisiblePasscodeField.becomeFirstResponder()
		}
	}
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if invisiblePasscodeField.isFirstResponder {
			invisiblePasscodeField.resignFirstResponder()
		}
	}
	private func configureInvisiblePasscodeField() {
		invisiblePasscodeField = UITextField()
		invisiblePasscodeField.keyboardType = .numberPad
		invisiblePasscodeField.isSecureTextEntry = true
		invisiblePasscodeField.delegate = self
		invisiblePasscodeField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
		view.addSubview(invisiblePasscodeField)
	}
	private func configureNavigationItems() {
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: R.string.localizable.cancel(), style: .plain, target: self, action: #selector(userTappedCancel))
	}
	private func configureLockView() {
		lockView = LockView(model)
		lockView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(lockView)
		lockView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		lockView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		lockView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
		lockView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
	}
	@objc func userTappedCancel() {
		if let finish = willFinishWithResult {
			finish(false)
		}
		dismiss(animated: true, completion: nil)
	}
	@objc func enteredPasscode(_ passcode: String) {
		shouldIgnoreTextFieldDelegateCalls = false
		clearPasscode()
	}
	func clearPasscode() {
		invisiblePasscodeField.text = ""
		for characterView in lockView.characters {
			characterView.setEmpty(true)
		}
	}
	func hideKeyboard() {
		invisiblePasscodeField.resignFirstResponder()
	}
	func showKeyboard() {
		invisiblePasscodeField.becomeFirstResponder()
	}
	func finish(withResult success: Bool, animated: Bool) {
		invisiblePasscodeField.resignFirstResponder()
		if let finish = willFinishWithResult {
			finish(success)
		} else {
			dismiss(animated: true, completion: nil)
		}
	}
	@objc func keyboardWillShow(_ notification: Notification) {
		if let userInfo = notification.userInfo {
			if let keyboardSize = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
				UIView.animate(withDuration: 0.1) { [weak self] () -> Void in
					guard let strongSelf = self else { return }
					strongSelf.lockView.bottomAnchor.constraint(equalTo: strongSelf.view.bottomAnchor, constant: -keyboardSize.height).isActive = true
				}
			}
		}
	}
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

extension LockPasscodeViewController: UITextFieldDelegate {
	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
		if shouldIgnoreTextFieldDelegateCalls {
			return false
		}
		let newString: String? = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
		let newLength: Int = newString?.count ?? 0
		if newLength > model.charCount {
			lockView.shake()
			textField.text = ""
			return false
		} else {
			for characterView in lockView.characters {
				let index: Int = lockView.characters.index(of: characterView)!
				characterView.setEmpty(index >= newLength)
			}
			return true
		}
	}
	@objc func textFieldDidChange(_ textField: UITextField) {
		if shouldIgnoreTextFieldDelegateCalls {
			return
		}
		let newString: String? = textField.text
		let newLength: Int = newString?.count ?? 0
		if newLength == model.charCount {
			shouldIgnoreTextFieldDelegateCalls = true
			textField.text = ""
			perform(#selector(enteredPasscode), with: newString, afterDelay: 0.3)
		}
	}
}
