// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class LockView: UIView {
	private var characterView = UIStackView()
	private var model: LockViewModel

	private var passcodeCharacters: [PasscodeCharacterView] {
		var characters = [PasscodeCharacterView]()
		for _ in 0..<model.charCount {
			let passcodeCharacterView = PasscodeCharacterView()
			passcodeCharacterView.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
			passcodeCharacterView.widthAnchor.constraint(equalToConstant: 20).isActive = true
			characters.append(passcodeCharacterView)
		}
		return characters
	}

	var lockTitle = UILabel()
	var characters: [PasscodeCharacterView]!

	private func configCharacterView() {
		characterView = UIStackView(arrangedSubviews: characters)
		characterView.axis = .horizontal
		characterView.distribution = .fillEqually
		characterView.alignment = .fill
		characterView.spacing = 20
		characterView.translatesAutoresizingMaskIntoConstraints = false
	}
	private func configLabel() {
		lockTitle.font = Fonts.light(size: 20)
		lockTitle.textAlignment = .center
		lockTitle.translatesAutoresizingMaskIntoConstraints = false
		lockTitle.textColor = Colors.appText
	}
	private func applyConstraints() {
		characterView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
		characterView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
		characterView.heightAnchor.constraint(equalToConstant: 20.0).isActive = true
		lockTitle.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
		lockTitle.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
		lockTitle.bottomAnchor.constraint(equalTo: characterView.topAnchor, constant: -20).isActive = true
	}
	private func addUiElements() {
		backgroundColor = Colors.appBackground
		addSubview(lockTitle)
		addSubview(characterView)
	}

	init(_ model: LockViewModel) {
		self.model = model
		super.init(frame: CGRect.zero)
		self.characters = passcodeCharacters
		configCharacterView()
		configLabel()
		addUiElements()
		applyConstraints()
	}

	func shake() {
		let keyPath = "position"
		let animation = CABasicAnimation(keyPath: keyPath)
		animation.duration = 0.07
		animation.repeatCount = 4
		animation.autoreverses = true
		animation.fromValue = NSValue(cgPoint: CGPoint(x: characterView.center.x - 10, y: characterView.center.y))
		animation.toValue = NSValue(cgPoint: CGPoint(x: characterView.center.x + 10, y: characterView.center.y))
		characterView.layer.add(animation, forKey: keyPath)
	}
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
