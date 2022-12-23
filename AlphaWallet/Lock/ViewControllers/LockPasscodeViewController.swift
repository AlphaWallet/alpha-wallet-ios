// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class LockPasscodeViewController: UIViewController {
	private let model: LockViewModel
    private lazy var invisiblePasscodeField: UITextField = {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.isSecureTextEntry = true
        textField.delegate = self
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)

        return textField
    }()

	var lockView: LockView!

    init(model: LockViewModel) {
		self.model = model
		super.init(nibName: nil, bundle: nil)
	}

	override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
		configureInvisiblePasscodeField()
		configureLockView()
	}
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if !invisiblePasscodeField.isFirstResponder && !model.isIncorrectMaxAttemptTimeSet {
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
		view.addSubview(invisiblePasscodeField)
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

	@objc func enteredPasscode(_ passcode: String) {
        model.shouldIgnoreTextFieldDelegateCalls = false
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

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

extension LockPasscodeViewController: UITextFieldDelegate {

	func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if model.shouldIgnoreTextFieldDelegateCalls {
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
                let index: Int = lockView.characters.firstIndex(of: characterView)!
				characterView.setEmpty(index >= newLength)
			}
			return true
		}
	}

	@objc func textFieldDidChange(_ textField: UITextField) {
        if model.shouldIgnoreTextFieldDelegateCalls {
			return
		}
		let newString: String? = textField.text
		let newLength: Int = newString?.count ?? 0
		if newLength == model.charCount {
            model.shouldIgnoreTextFieldDelegateCalls = true
			textField.text = ""
			perform(#selector(enteredPasscode), with: newString, afterDelay: 0.3)
		}
	}
}
