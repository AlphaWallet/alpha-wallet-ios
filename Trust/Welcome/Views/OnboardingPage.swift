// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

final class OnboardingPage: UICollectionViewCell {
    static let identifier = "Page"
    let style = OnboardingPageStyle()

    private var imageView: UIImageView!
    private var titleLabel: UILabel!

    override var reuseIdentifier: String? {
        return OnboardingPage.identifier
    }

    var model = OnboardingPageViewModel() {
        didSet {
            imageView.image = model.image
            titleLabel.text = model.title
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit

        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.textColor = style.titleColor
        titleLabel.font = style.titleFont
        titleLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [
            titleLabel,
            imageView,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 80
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
			
            imageView.heightAnchor.constraint(equalToConstant: 240),
        ])
    }
}
