// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import CoreImage
import MBProgressHUD

//Careful to fit in shorter phone like iPhone 5s without needing to scroll
class RequestViewController: UIViewController {
	private let roundedBackground: RoundedBackground = {
		let roundedBackground = RoundedBackground()
		roundedBackground.translatesAutoresizingMaskIntoConstraints = false
		return roundedBackground
	}()

	private let scrollView = UIScrollView()

	private lazy var instructionLabel: UILabel = {
		let label = UILabel()
		label.textColor = viewModel.labelColor
		label.font = viewModel.instructionFont
		label.adjustsFontSizeToFitWidth = true
		label.text = viewModel.instructionText
		return label
	}()

	private lazy var imageView: UIImageView = {
		let imageView = UIImageView()
		return imageView
	}()

	private lazy var addressContainerView: UIView = {
		let v = UIView()
		v.backgroundColor = viewModel.addressBackgroundColor
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

	private lazy var ensContainerView: UIView = {
		let v = UIView()
		v.backgroundColor = viewModel.addressBackgroundColor
        v.isHidden = true
		return v
	}()

	private lazy var ensLabel: UILabel = {
		let label = UILabel(frame: .zero)
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = viewModel.labelColor
		label.font = viewModel.addressFont
		label.textAlignment = .center
		label.minimumScaleFactor = 0.5
		label.adjustsFontSizeToFitWidth = true
		return label
	}()

	private let viewModel: RequestViewModel
	private let buttonsBar = ButtonsBar(numberOfButtons: 1)

	init(viewModel: RequestViewModel) {
		self.viewModel = viewModel

		super.init(nibName: nil, bundle: nil)

		view.backgroundColor = viewModel.backgroundColor
		view.addSubview(roundedBackground)

		ensContainerView.addSubview(ensLabel)

		addressContainerView.addSubview(addressLabel)

		scrollView.translatesAutoresizingMaskIntoConstraints = false
		roundedBackground.addSubview(scrollView)

		let stackView = [
			.spacer(height: ScreenChecker().isNarrowScreen ? 20 : 30),
			instructionLabel,
			.spacer(height: ScreenChecker().isNarrowScreen ? 20 : 50),
			imageView,
		].asStackView(axis: .vertical, alignment: .center)
		stackView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.addSubview(stackView)

		ensContainerView.translatesAutoresizingMaskIntoConstraints = false
		roundedBackground.addSubview(ensContainerView)

        addressContainerView.translatesAutoresizingMaskIntoConstraints = false
		roundedBackground.addSubview(addressContainerView)

		let footerBar = UIView()
		footerBar.translatesAutoresizingMaskIntoConstraints = false
		footerBar.backgroundColor = .clear
		roundedBackground.addSubview(footerBar)

		footerBar.addSubview(buttonsBar)

		let qrCodeDimensions: CGFloat
		if ScreenChecker().isNarrowScreen {
			qrCodeDimensions = 230
		} else {
			qrCodeDimensions = 260
		}
		NSLayoutConstraint.activate([
			//Leading/trailing anchor needed to make label fit when on narrow iPhones
			ensLabel.anchorsConstraint(to: ensContainerView, edgeInsets: .init(top: 20, left: 10, bottom: 20, right: 10)),
			addressLabel.anchorsConstraint(to: addressContainerView, edgeInsets: .init(top: 20, left: 10, bottom: 20, right: 10)),

			imageView.widthAnchor.constraint(equalToConstant: qrCodeDimensions),
			imageView.heightAnchor.constraint(equalToConstant: qrCodeDimensions),

			stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
			stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
			stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
			stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

			scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			scrollView.topAnchor.constraint(equalTo: view.topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

			buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
			buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
			buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
			buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

			footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
			footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

			ensContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			ensContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			ensContainerView.bottomAnchor.constraint(equalTo: addressContainerView.topAnchor, constant: ScreenChecker().isNarrowScreen ? -10 : -20),

			addressContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			addressContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			addressContainerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: -20),

			roundedBackground.createConstraintsWithContainer(view: view),
		])

		changeQRCode(value: 0)

		configure()
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		addressContainerView.cornerRadius = addressContainerView.frame.size.height / 2
		ensContainerView.cornerRadius = ensContainerView.frame.size.height / 2
	}

	private func configure() {
		buttonsBar.configure()
		let copyButton = buttonsBar.buttons[0]
		copyButton.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)
		copyButton.setTitle(viewModel.copyWalletText, for: .normal)

		resolveEns()
	}

	private func resolveEns() {
		let serverToResolveEns = RPCServer.main
		let address = viewModel.myAddress
		ENSReverseLookupCoordinator(server: serverToResolveEns).getENSNameFromResolver(forAddress: address) { [weak self] result in
			guard let strongSelf = self else { return }
			if let ensName = result.value {
                strongSelf.ensLabel.text = ensName
				strongSelf.ensContainerView.isHidden = false
				strongSelf.ensContainerView.cornerRadius = strongSelf.ensContainerView.frame.size.height / 2
			} else {
				strongSelf.ensLabel.text = nil
				strongSelf.ensContainerView.isHidden = true
			}
		}
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

		showFeedback()
	}

	private func showFeedback() {
		//TODO sound too
		let feedbackGenerator = UINotificationFeedbackGenerator()
		feedbackGenerator.prepare()
		feedbackGenerator.notificationOccurred(.success)
	}

	func generateQRCode(from string: String) -> UIImage? {
		return string.toQRCode()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
