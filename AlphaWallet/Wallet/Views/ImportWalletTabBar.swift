// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol ImportWalletTabBarDelegate: class {
	func didPressImportWalletTab(tab: ImportWalletTab, in tabBar: ImportWalletTabBar)
}

class ImportWalletTabBar: UIView {
	private let mnemonicButton = UIButton(type: .system)
	private let keystoreButton = UIButton(type: .system)
	private let privateKeyButton = UIButton(type: .system)
	private let watchButton = UIButton(type: .system)
	private let tabHighlightView = UIView()
	private var highlightBarHorizontalConstraints: [NSLayoutConstraint]?
	private lazy var viewModel = ImportWalletTabBarViewModel(tab: tab)

	var tab: ImportWalletTab = .mnemonic {
		didSet {
			viewModel.currentTab = tab
			delegate?.didPressImportWalletTab(tab: tab, in: self)
			configure()
		}
	}
	weak var delegate: ImportWalletTabBarDelegate?

	override init(frame: CGRect) {
		super.init(frame: frame)

		backgroundColor = viewModel.backgroundColor

		mnemonicButton.setTitle(R.string.localizable.mnemonicShorter().uppercased(), for: .normal)
		mnemonicButton.titleLabel?.font = viewModel.font
		mnemonicButton.addTarget(self, action: #selector(showMnemonicTab), for: .touchUpInside)

		keystoreButton.setTitle(ImportSelectionType.keystore.title.uppercased(), for: .normal)
		keystoreButton.titleLabel?.font = viewModel.font
		keystoreButton.addTarget(self, action: #selector(showKeystoreTab), for: .touchUpInside)

		privateKeyButton.setTitle(ImportSelectionType.privateKey.title.uppercased(), for: .normal)
		privateKeyButton.titleLabel?.font = viewModel.font
		privateKeyButton.addTarget(self, action: #selector(showPrivateKeyTab), for: .touchUpInside)

		watchButton.setTitle(ImportSelectionType.watch.title.uppercased(), for: .normal)
		watchButton.titleLabel?.font = viewModel.font
		watchButton.addTarget(self, action: #selector(showWatchTab), for: .touchUpInside)

		let fullWidthBar = UIView()
		fullWidthBar.translatesAutoresizingMaskIntoConstraints = false
		fullWidthBar.backgroundColor = .clear
		fullWidthBar.isUserInteractionEnabled = false
		addSubview(fullWidthBar)

		tabHighlightView.translatesAutoresizingMaskIntoConstraints = false
		tabHighlightView.backgroundColor = viewModel.barHighlightedColor
		fullWidthBar.addSubview(tabHighlightView)

		let buttonsStackView = [mnemonicButton, keystoreButton, privateKeyButton, watchButton].asStackView(spacing: 20)
		buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(buttonsStackView)

		let barHeightConstraint = fullWidthBar.heightAnchor.constraint(equalToConstant: 44)
		barHeightConstraint.priority = .defaultHigh
		let stackViewLeadingConstraint = buttonsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 17)
		stackViewLeadingConstraint.priority = .defaultHigh
		let stackViewTrailingConstraint = buttonsStackView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -17)
		stackViewTrailingConstraint.priority = .defaultHigh
		NSLayoutConstraint.activate([
			stackViewLeadingConstraint,
			stackViewTrailingConstraint,
			buttonsStackView.topAnchor.constraint(equalTo: topAnchor),
			buttonsStackView.bottomAnchor.constraint(equalTo: bottomAnchor),

			keystoreButton.widthAnchor.constraint(equalTo: mnemonicButton.widthAnchor),
            keystoreButton.widthAnchor.constraint(equalTo: privateKeyButton.widthAnchor),
			keystoreButton.widthAnchor.constraint(equalTo: watchButton.widthAnchor),

			fullWidthBar.leadingAnchor.constraint(equalTo: leadingAnchor),
			fullWidthBar.trailingAnchor.constraint(equalTo: trailingAnchor),
			barHeightConstraint,
			fullWidthBar.topAnchor.constraint(equalTo: topAnchor),
			fullWidthBar.bottomAnchor.constraint(equalTo: bottomAnchor),

			tabHighlightView.topAnchor.constraint(equalTo: fullWidthBar.topAnchor),
			tabHighlightView.bottomAnchor.constraint(equalTo: fullWidthBar.bottomAnchor, constant: 20),
		])

        configure()
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}

	@objc func showMnemonicTab() {
		tab = .mnemonic
	}

	@objc func showKeystoreTab() {
		tab = .keystore
	}

	@objc func showPrivateKeyTab() {
		tab = .privateKey
	}

	@objc func showWatchTab() {
		tab = .watch
	}

	private func configure() {
		configureButtonColors()
		configureHighlightedBar()
	}

	private func configureButtonColors() {
		mnemonicButton.setTitleColor(viewModel.titleColor(for: .mnemonic), for: .normal)
		keystoreButton.setTitleColor(viewModel.titleColor(for: .keystore), for: .normal)
		privateKeyButton.setTitleColor(viewModel.titleColor(for: .privateKey), for: .normal)
		watchButton.setTitleColor(viewModel.titleColor(for: .watch), for: .normal)
	}

	private func configureHighlightedBar() {
		tabHighlightView.cornerRadius = 14

		var button: UIButton
		switch tab {
		case .mnemonic:
			button = mnemonicButton
		case .keystore:
			button = keystoreButton
		case .privateKey:
			button = privateKeyButton
		case .watch:
			button = watchButton
		}

		if let previousConstraints = highlightBarHorizontalConstraints {
			NSLayoutConstraint.deactivate(previousConstraints)
		}
		highlightBarHorizontalConstraints = [
			tabHighlightView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: -10),
			tabHighlightView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 10),
		]
		if let constraints = highlightBarHorizontalConstraints {
			NSLayoutConstraint.activate(constraints)
		}
		UIView.animate(withDuration: 0.3) {
			self.layoutIfNeeded()
		}
	}
}
