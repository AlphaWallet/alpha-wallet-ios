// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class PasscodeCharacterView: UIView {
	private var isEmpty = true
    private let filledImageView: UIImageView = UIImageView(image: UIImage(systemName: "circle.fill"))
    private let emptyImageView: UIImageView = UIImageView(image: UIImage(systemName: "circle"))

    override init(frame: CGRect) {
        isEmpty = true
        super.init(frame: frame)
        setupView()
        updateView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        filledImageView.image = filledImageView.image?.withTintColor(Configuration.Color.Semantic.symbol, renderingMode: .alwaysOriginal)
        emptyImageView.image = emptyImageView.image?.withTintColor(Configuration.Color.Semantic.symbol, renderingMode: .alwaysOriginal)
        addSubview(filledImageView)
        addSubview(emptyImageView)
        NSLayoutConstraint.activate([
            filledImageView.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier: 1.0),
            trailingAnchor.constraint(equalToSystemSpacingAfter: filledImageView.trailingAnchor, multiplier: 1.0),
            filledImageView.topAnchor.constraint(equalToSystemSpacingBelow: filledImageView.topAnchor, multiplier: 1.0),
            bottomAnchor.constraint(equalToSystemSpacingBelow: filledImageView.bottomAnchor, multiplier: 1.0),
            emptyImageView.leadingAnchor.constraint(equalToSystemSpacingAfter: leadingAnchor, multiplier: 1.0),
            trailingAnchor.constraint(equalToSystemSpacingAfter: emptyImageView.trailingAnchor, multiplier: 1.0),
            emptyImageView.topAnchor.constraint(equalToSystemSpacingBelow: filledImageView.topAnchor, multiplier: 1.0),
            bottomAnchor.constraint(equalToSystemSpacingBelow: emptyImageView.bottomAnchor, multiplier: 1.0)
        ])
    }

	private func updateView() {
        filledImageView.isHidden = isEmpty
        emptyImageView.isHidden = !isEmpty
	}

	func setEmpty(_ isEmpty: Bool) {
		if self.isEmpty != isEmpty {
			self.isEmpty = isEmpty
			updateView()
		}
	}
}
