// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AlphaWalletFilterViewDelegate: class {
	func didPressWalletFilter(filter: AlphaWalletFilter, in filterView: AlphaWalletFilterView)
}

class AlphaWalletFilterView: UIView {
	let allButton = UIButton(type: .system)
	let currencyButton = UIButton(type: .system)
	let assetsButton = UIButton(type: .system)
	let highlightedBar = UIView()
	var filter: AlphaWalletFilter = .all {
		didSet {
			viewModel.currentFilter = filter
			delegate?.didPressWalletFilter(filter: filter, in: self)
			configureButtonColors()
			configureHighlightedBar()
		}
	}
	var highlightBarHorizontalConstraints: [NSLayoutConstraint]?
	weak var delegate: AlphaWalletFilterViewDelegate?
	lazy var viewModel = AlphaWalletFilterViewModel(filter: filter)

	override init(frame: CGRect) {
		super.init(frame: frame)

		backgroundColor = viewModel.backgroundColor

		allButton.setTitle(R.string.localizable.aWalletContentsFilterAllTitle(), for: .normal)
		allButton.titleLabel?.font = viewModel.font
		allButton.addTarget(self, action: #selector(showAll), for: .touchUpInside)

		currencyButton.setTitle(R.string.localizable.aWalletContentsFilterCurrencyOnlyTitle(), for: .normal)
		currencyButton.titleLabel?.font = viewModel.font
		currencyButton.addTarget(self, action: #selector(showCurrencyOnly), for: .touchUpInside)

		assetsButton.setTitle(R.string.localizable.aWalletContentsFilterAssetsOnlyTitle(), for: .normal)
		assetsButton.titleLabel?.font = viewModel.font
		assetsButton.addTarget(self, action: #selector(showAssetsOnly), for: .touchUpInside)

		let buttonsStackView = UIStackView(arrangedSubviews: [allButton, currencyButton, assetsButton])
		buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
		buttonsStackView.axis = .horizontal
		buttonsStackView.spacing = 20
		buttonsStackView.distribution = .fill
		addSubview(buttonsStackView)

		let fullWidthBar = UIView()
		fullWidthBar.translatesAutoresizingMaskIntoConstraints = false
		fullWidthBar.backgroundColor = viewModel.barUnhighlightedColor
		addSubview(fullWidthBar)

		highlightedBar.translatesAutoresizingMaskIntoConstraints = false
		highlightedBar.backgroundColor = viewModel.barHighlightedColor
		fullWidthBar.addSubview(highlightedBar)

		let barHeightConstraint = fullWidthBar.heightAnchor.constraint(equalToConstant: 2)
		barHeightConstraint.priority = .defaultHigh
		let stackViewLeadingConstraint = buttonsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 17)
		stackViewLeadingConstraint.priority = .defaultHigh
		let stackViewTrailingConstraint = buttonsStackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -17)
		stackViewTrailingConstraint.priority = .defaultHigh
		NSLayoutConstraint.activate([
			stackViewLeadingConstraint,
			stackViewTrailingConstraint,
			buttonsStackView.topAnchor.constraint(equalTo: topAnchor),
			buttonsStackView.bottomAnchor.constraint(equalTo: fullWidthBar.topAnchor),

			fullWidthBar.leadingAnchor.constraint(equalTo: leadingAnchor),
			fullWidthBar.trailingAnchor.constraint(equalTo: trailingAnchor),
			barHeightConstraint,
			fullWidthBar.bottomAnchor.constraint(equalTo: bottomAnchor),

			highlightedBar.topAnchor.constraint(equalTo: fullWidthBar.topAnchor),
			highlightedBar.bottomAnchor.constraint(equalTo: fullWidthBar.bottomAnchor),
		])

		configureButtonColors()
		configureHighlightedBar()
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	@objc func showAll() {
		filter = .all
	}

	@objc func showCurrencyOnly() {
		filter = .currencyOnly
	}

	@objc func showAssetsOnly() {
		filter = .assetsOnly
	}

	func configureButtonColors() {
		allButton.setTitleColor(viewModel.colorForFilter(filter: .all), for: .normal)
		currencyButton.setTitleColor(viewModel.colorForFilter(filter: .currencyOnly), for: .normal)
		assetsButton.setTitleColor(viewModel.colorForFilter(filter: .assetsOnly), for: .normal)
	}

	func configureHighlightedBar() {
		var button: UIButton
		switch filter {
		case .all:
			button = allButton
		case .currencyOnly:
			button = currencyButton
		case .assetsOnly:
			button = assetsButton
		}

		if let previousConstraints = highlightBarHorizontalConstraints {
			NSLayoutConstraint.deactivate(previousConstraints)
		}
		highlightBarHorizontalConstraints = [
			highlightedBar.leadingAnchor.constraint(equalTo: button.leadingAnchor),
			highlightedBar.trailingAnchor.constraint(equalTo: button.trailingAnchor),
		]
		if let constraints = highlightBarHorizontalConstraints {
			NSLayoutConstraint.activate(constraints)
		}
		UIView.animate(withDuration: 0.7) {
			self.layoutIfNeeded()
		}
	}
}
