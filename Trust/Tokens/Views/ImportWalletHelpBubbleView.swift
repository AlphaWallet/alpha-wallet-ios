// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class ImportWalletHelpBubbleView: UIView {
	var importWalletHelpBubbleLayer = CAShapeLayer()
	let titleLabel = UILabel()
	let descriptionLabel = UILabel()

	init() {
		super.init(frame: .zero)

		importWalletHelpBubbleLayer.path = createImportWalletHelpBubblePath().cgPath
		importWalletHelpBubbleLayer.fillColor = Colors.appWhite.cgColor
		importWalletHelpBubbleLayer.strokeColor = UIColor.clear.cgColor
		layer.addSublayer(importWalletHelpBubbleLayer)

		titleLabel.translatesAutoresizingMaskIntoConstraints = false

		descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

		let stackView = UIStackView(arrangedSubviews: [
			titleLabel,
			descriptionLabel,
		])
		stackView.translatesAutoresizingMaskIntoConstraints = false
		stackView.axis = .vertical
		stackView.spacing = 7
		stackView.distribution = .fill
		stackView.setContentHuggingPriority(UILayoutPriority.required, for: .vertical)
		addSubview(stackView)

		configure(viewModel: ImportWalletHelpBubbleViewViewModel())

		let helpTextMargin = CGFloat(37)
		translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: helpTextMargin),
			stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -helpTextMargin),
			stackView.topAnchor.constraint(equalTo: topAnchor, constant: helpTextMargin),
			stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -helpTextMargin),
		])
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		importWalletHelpBubbleLayer.frame = bounds
		importWalletHelpBubbleLayer.path = createImportWalletHelpBubblePath().cgPath
	}

	func createImportWalletHelpBubblePath() -> UIBezierPath {
		let triangleWidth = CGFloat(20)
		let triangleHeight = CGFloat(12)
		let path = UIBezierPath(roundedRect: CGRect(x: 0, y: triangleHeight, width: bounds.size.width, height: bounds.size.height - triangleHeight), cornerRadius: 20)
		let triangle = UIBezierPath()
		triangle.move(to: CGPoint(x: bounds.size.width / 2, y: 0))
		triangle.addLine(to: CGPoint(x: bounds.size.width / 2 - triangleWidth / 2, y: triangleHeight))
		triangle.addLine(to: CGPoint(x: bounds.size.width / 2 + triangleWidth / 2, y: triangleHeight))
		path.append(triangle)
		return path
	}

	private func configure(viewModel: ImportWalletHelpBubbleViewViewModel) {
		titleLabel.textAlignment = .center
		titleLabel.textColor = viewModel.textColor
		titleLabel.font = viewModel.textFont
		titleLabel.text = R.string.localizable.aWalletImportWalletBubbleTitle()

		descriptionLabel.numberOfLines = 0
		descriptionLabel.textAlignment = .center
		descriptionLabel.textColor = viewModel.descriptionColor
		descriptionLabel.font = viewModel.descriptionFont
		descriptionLabel.text = R.string.localizable.aWalletImportWalletBubbleDescription()
	}
}
