// Copyright © 2018 Stormbird PTE. LTD.
// Copyright SIX DAY LLC

import Foundation
import UIKit
import CoreImage
import MBProgressHUD
import StackViewController

//Careful to fit in shorter phone like iPhone 5s without needing to scroll
class RequestViewController: UIViewController {
	private let roundedBackground: RoundedBackground = {
		let roundedBackground = RoundedBackground()
		roundedBackground.translatesAutoresizingMaskIntoConstraints = false
		return roundedBackground
	}()

	private let stackViewController = StackViewController()

	private lazy var imageView: UIImageView = {
		let imageView = UIImageView()
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	private lazy var copyButton: UIButton = {
		let button = Button(size: .normal, style: .border)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.titleLabel?.font = viewModel.buttonFont
		button.setTitle("    \(viewModel.copyWalletText)    ", for: .normal)
		button.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		button.backgroundColor = viewModel.buttonBackgroundColor
		button.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)
		button.cornerRadius = Metrics.CornerRadius.button
		return button
	}()

	private lazy var addressHintLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = viewModel.labelColor
		label.font = viewModel.addressHintFont
		label.adjustsFontSizeToFitWidth = true
		label.text = viewModel.headlineText
		return label
	}()

	private lazy var instructionLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = viewModel.labelColor
		label.font = viewModel.instructionFont
		label.adjustsFontSizeToFitWidth = true
		label.text = viewModel.instructionText
		return label
	}()

	private lazy var addressContainerView: UIView = {
		let v = UIView()
		v.translatesAutoresizingMaskIntoConstraints = false
		v.backgroundColor = viewModel.addressBackgroundColor
        v.cornerRadius = Metrics.CornerRadius.textbox
		return v
	}()

	private lazy var addressLabel: UILabel = {
		let label = UILabel(frame: .zero)
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = viewModel.labelColor
		label.font = viewModel.addressFont
		label.text = viewModel.myAddressText
		label.textAlignment = .center
		label.minimumScaleFactor = 0.5
		label.adjustsFontSizeToFitWidth = true
		return label
	}()

	private let viewModel: RequestViewModel

	init(viewModel: RequestViewModel) {
		self.viewModel = viewModel

		stackViewController.scrollView.alwaysBounceVertical = true

		super.init(nibName: nil, bundle: nil)

		view.backgroundColor = viewModel.backgroundColor
		view.addSubview(roundedBackground)

		addressContainerView.addSubview(addressLabel)

		displayStackViewController()

		stackViewController.addItem(addressHintLabel)
		stackViewController.addItem(instructionLabel)

		stackViewController.addItem(addressContainerView)
		stackViewController.addItem(copyButton)

		stackViewController.addItem(UIView.spacer(height: 16))
		stackViewController.addItem(imageView)

		let addressContainerLeadingAnchorConstraint = addressContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10)
		addressContainerLeadingAnchorConstraint.priority = .defaultLow
		let addressContainerTrailingAnchorConstraint = addressContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 10)
		addressContainerTrailingAnchorConstraint.priority = .defaultLow
		NSLayoutConstraint.activate([
			addressContainerLeadingAnchorConstraint,
			addressContainerTrailingAnchorConstraint,

			//Leading/trailing anchor needed to make label fit when on narrow iPhones
			addressLabel.centerXAnchor.constraint(lessThanOrEqualTo: addressContainerView.centerXAnchor),
			addressLabel.anchorsConstraint(to: addressContainerView, edgeInsets: .init(top: 20, left: 10, bottom: 20, right: 10)),

			imageView.widthAnchor.constraint(equalToConstant: 260),
			imageView.heightAnchor.constraint(equalToConstant: 260),

			roundedBackground.createConstraintsWithContainer(view: view),
		])

		changeQRCode(value: 0)
	}

	private func displayStackViewController() {
		addChild(stackViewController)
		roundedBackground.addSubview(stackViewController.view)
		_ = stackViewController.view.activateSuperviewHuggingConstraints()
		stackViewController.didMove(toParent: self)

		stackViewController.stackView.spacing = 10
		stackViewController.stackView.alignment = .center
		stackViewController.stackView.layoutMargins = UIEdgeInsets(top: 20, left: 15, bottom: 0, right: 15)
		stackViewController.stackView.isLayoutMarginsRelativeArrangement = true
	}

	@objc func textFieldDidChange(_ textField: UITextField) {
		changeQRCode(value: Int(textField.text ?? "0") ?? 0)
	}

	func changeQRCode(value: Int) {
		let string = viewModel.myAddressText

		// EIP67 format not being used much yet, use hex value for now
		// let string = "ethereum:\(account.address.address)?value=\(value)"

		DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
			let image = strongSelf.generateQRCode(from: string)
			DispatchQueue.main.async {
				strongSelf.imageView.image = image
			}
		}
	}

	@objc func copyAddress() {
		UIPasteboard.general.string = viewModel.myAddressText

		let hud = MBProgressHUD.showAdded(to: view, animated: true)
		hud.mode = .text
		hud.label.text = viewModel.addressCopiedText
		hud.hide(animated: true, afterDelay: 1.5)
	}

	func generateQRCode(from string: String) -> UIImage? {
		return string.toQRCode()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
