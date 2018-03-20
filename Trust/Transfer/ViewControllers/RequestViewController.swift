// Copyright © 2018 Stormbird PTE. LTD.
// Copyright SIX DAY LLC

import Foundation
import UIKit
import CoreImage
import MBProgressHUD
import StackViewController

//Careful to fit in shorter phone like iPhone 5s without needing to scroll
class RequestViewController: UIViewController {
	//roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
	let roundedBackground: UIView = {
		let roundedBackground = UIView()
		roundedBackground.translatesAutoresizingMaskIntoConstraints = false
		roundedBackground.backgroundColor = Colors.appWhite
		roundedBackground.cornerRadius = 20
		return roundedBackground
	}()

	let stackViewController = StackViewController()

	lazy var imageView: UIImageView = {
		let imageView = UIImageView()
		imageView.translatesAutoresizingMaskIntoConstraints = false
		return imageView
	}()

	lazy var copyButton: UIButton = {
		let button = Button(size: .normal, style: .border)
		button.translatesAutoresizingMaskIntoConstraints = false
		button.titleLabel?.font = viewModel.buttonFont
		button.setTitle("    \(viewModel.copyWalletText)    ", for: .normal)
		button.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		button.backgroundColor = viewModel.buttonBackgroundColor
		button.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)
		return button
	}()

	lazy var addressHintLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = viewModel.labelColor
		label.font = viewModel.addressHintFont
		label.adjustsFontSizeToFitWidth = true
		label.text = viewModel.headlineText
		return label
	}()

	lazy var instructionLabel: UILabel = {
		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = viewModel.labelColor
		label.font = viewModel.instructionFont
		label.adjustsFontSizeToFitWidth = true
		label.text = viewModel.instructionText
		return label
	}()

	lazy var addressContainerView: UIView = {
		let v = UIView()
		v.translatesAutoresizingMaskIntoConstraints = false
		v.backgroundColor = viewModel.addressBackgroundColor
		return v
	}()

	lazy var addressLabel: UILabel = {
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

	let viewModel: RequestViewModel

	init(
			viewModel: RequestViewModel
	) {
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
		let marginToHideBottomRoundedCorners = CGFloat(30)
		NSLayoutConstraint.activate([
			roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
			roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),

			addressContainerLeadingAnchorConstraint,
			addressContainerTrailingAnchorConstraint,

			//Leading/trailing anchor needed to make label fit when on narrow iPhones
			addressLabel.leadingAnchor.constraint(greaterThanOrEqualTo: addressContainerView.leadingAnchor, constant: 10),
			addressLabel.trailingAnchor.constraint(lessThanOrEqualTo: addressContainerView.trailingAnchor, constant: -10),
			addressLabel.centerXAnchor.constraint(lessThanOrEqualTo: addressContainerView.centerXAnchor),
			addressLabel.topAnchor.constraint(equalTo: addressContainerView.topAnchor, constant: 20),
			addressLabel.bottomAnchor.constraint(equalTo: addressContainerView.bottomAnchor, constant: -20),

			imageView.widthAnchor.constraint(equalToConstant: 260),
			imageView.heightAnchor.constraint(equalToConstant: 260),
		])

		changeQRCode(value: 0)
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		roundCornersBasedOnHeight()
	}

	private func roundCornersBasedOnHeight() {
		copyButton.cornerRadius = copyButton.frame.size.height / 2
		addressContainerView.cornerRadius = addressContainerView.frame.size.height / 2
	}

	private func displayStackViewController() {
		addChildViewController(stackViewController)
		roundedBackground.addSubview(stackViewController.view)
		_ = stackViewController.view.activateSuperviewHuggingConstraints()
		stackViewController.didMove(toParentViewController: self)

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

		DispatchQueue.global(qos: .background).async {
			let image = self.generateQRCode(from: string)
			DispatchQueue.main.async {
				self.imageView.image = image
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
