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
	private let copyEnsButton = UIButton(type: .system)
	private let copyAddressButton = UIButton(type: .system)

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
		label.textColor = viewModel.addressLabelColor
		label.font = viewModel.addressFont
		label.text = viewModel.myAddressText
		label.textAlignment = .center
		label.numberOfLines = 0
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
		label.textColor = viewModel.addressLabelColor
		label.font = viewModel.addressFont
		label.textAlignment = .center
		label.minimumScaleFactor = 0.5
		label.adjustsFontSizeToFitWidth = true
		return label
	}()

	private let viewModel: RequestViewModel

	init(viewModel: RequestViewModel) {
		self.viewModel = viewModel

		super.init(nibName: nil, bundle: nil)

        title = R.string.localizable.aSettingsContentsMyWalletAddress()

		view.backgroundColor = viewModel.backgroundColor
		view.addSubview(roundedBackground)

		copyEnsButton.addTarget(self, action: #selector(copyEns), for: .touchUpInside)
        copyEnsButton.setContentHuggingPriority(.required, for: .horizontal)

		let ensStackView = [.spacerWidth(7), ensLabel, .spacerWidth(10), copyEnsButton, .spacerWidth(7)].asStackView(axis: .horizontal)
		ensStackView.addSubview(forBackgroundColor: viewModel.addressBackgroundColor)
		ensStackView.translatesAutoresizingMaskIntoConstraints = false
		ensContainerView.addSubview(ensStackView)

		copyAddressButton.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)
		copyAddressButton.setContentHuggingPriority(.required, for: .horizontal)

		let addressStackView = [.spacerWidth(7), addressLabel, .spacerWidth(10), copyAddressButton, .spacerWidth(7)].asStackView(axis: .horizontal)
		addressStackView.addSubview(forBackgroundColor: viewModel.addressBackgroundColor)
		addressStackView.translatesAutoresizingMaskIntoConstraints = false
		addressContainerView.addSubview(addressStackView)

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

		let qrCodeDimensions: CGFloat
		if ScreenChecker().isNarrowScreen {
			qrCodeDimensions = 230
		} else {
			qrCodeDimensions = 260
		}
		NSLayoutConstraint.activate([
			//Leading/trailing anchor needed to make label fit when on narrow iPhones
			ensStackView.anchorsConstraint(to: ensContainerView, edgeInsets: .init(top: 14, left: 20, bottom: 14, right: 20)),
			addressStackView.anchorsConstraint(to: addressContainerView, edgeInsets: .init(top: 14, left: 20, bottom: 14, right: 20)),

			imageView.widthAnchor.constraint(equalToConstant: qrCodeDimensions),
			imageView.heightAnchor.constraint(equalToConstant: qrCodeDimensions),

			stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
			stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
			stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
			stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

			scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			scrollView.topAnchor.constraint(equalTo: view.topAnchor),
			scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            ensContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			ensContainerView.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 40),

			addressContainerView.topAnchor.constraint(equalTo: ensContainerView.bottomAnchor, constant: ScreenChecker().isNarrowScreen ? 10 : 20),
			addressContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			addressContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

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
		copyEnsButton.setImage(R.image.copy(), for: .normal)

		copyAddressButton.setImage(R.image.copy(), for: .normal)

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

	@objc func copyEns() {
		UIPasteboard.general.string = ensLabel.text ?? ""

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

fileprivate extension UIStackView {
	func addSubview(forBackgroundColor backgroundColor: UIColor) {
		let v = UIView(frame: bounds)
		v.backgroundColor = backgroundColor
		v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		insertSubview(v, at: 0)
	}
}
