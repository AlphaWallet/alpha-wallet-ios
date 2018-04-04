// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TicketImportStatusViewControllerDelegate: class {
	func didPressDone(in viewController: TicketImportStatusViewController)
}

class TicketImportStatusViewController: UIViewController {
	weak var delegate: TicketImportStatusViewControllerDelegate?
	let background = UIView()
	let imageView = UIImageView()
	let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
	let titleLabel = UILabel()
	let actionButton = UIButton()

	init() {
		super.init(nibName: nil, bundle: nil)
		view.backgroundColor = .clear

		let visualEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
		visualEffectView.translatesAutoresizingMaskIntoConstraints = false
		view.insertSubview(visualEffectView, at: 0)

		let imageHolder = UIView()

		activityIndicator.translatesAutoresizingMaskIntoConstraints = false
		activityIndicator.hidesWhenStopped = true
		imageHolder.addSubview(activityIndicator)

		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.isHidden = true
		imageHolder.addSubview(imageView)

		view.addSubview(background)
		background.translatesAutoresizingMaskIntoConstraints = false

		actionButton.addTarget(self, action: #selector(done), for: .touchUpInside)

		let stackView = UIStackView(arrangedSubviews: [
			.spacer(height: 20),
			imageHolder,
			.spacer(height: 20),
			titleLabel,
			.spacer(height: 20),
			actionButton,
			.spacer(height: 18)
		])
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.spacing = 0
		stackView.distribution = .fill
		background.addSubview(stackView)

		NSLayoutConstraint.activate([
			visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
			visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

			imageView.widthAnchor.constraint(equalToConstant: 70),
			imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor),
			imageView.centerXAnchor.constraint(equalTo: imageHolder.centerXAnchor),
			imageView.centerYAnchor.constraint(equalTo: imageHolder.centerYAnchor),

			activityIndicator.centerXAnchor.constraint(equalTo: imageHolder.centerXAnchor),
			activityIndicator.centerYAnchor.constraint(equalTo: imageHolder.centerYAnchor),

			imageHolder.heightAnchor.constraint(equalTo: imageView.heightAnchor),

			actionButton.heightAnchor.constraint(equalToConstant: 47),

			stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 40),
			stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -40),
			stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
			stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -16),

			background.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 42),
			background.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -42),
			background.centerYAnchor.constraint(equalTo: view.centerYAnchor)
		])
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(viewModel: TicketImportStatusViewControllerViewModel) {
		background.backgroundColor = viewModel.contentsBackgroundColor
		background.layer.cornerRadius = 20

		activityIndicator.color = viewModel.activityIndicatorColor

		if viewModel.showActivityIndicator {
			activityIndicator.startAnimating()
		} else {
			activityIndicator.stopAnimating()
		}

		imageView.isHidden = viewModel.showActivityIndicator
		imageView.image = viewModel.image

		titleLabel.numberOfLines = 0
		titleLabel.textColor = viewModel.titleColor
		titleLabel.font = viewModel.titleFont
		titleLabel.textAlignment = .center
		titleLabel.text = viewModel.titleLabelText

		actionButton.setTitleColor(viewModel.actionButtonTitleColor, for: .normal)
		actionButton.setBackgroundColor(viewModel.actionButtonBackgroundColor, forState: .normal)
		actionButton.titleLabel?.font = viewModel.actionButtonTitleFont
		actionButton.setTitle(viewModel.actionButtonTitle, for: .normal)
		actionButton.layer.masksToBounds = true
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		actionButton.layer.cornerRadius = actionButton.frame.size.height / 2
	}

	@objc func done() {
		if let delegate = delegate {
			delegate.didPressDone(in: self)
		} else {
			dismiss(animated: true)
		}
	}
}
