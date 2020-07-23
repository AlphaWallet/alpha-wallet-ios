// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class HardcodedTokenViewControllerHeaderView: UIView {
    var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    let balanceLabel = UILabel()
    let descriptionLabel = UILabel()

    init() {
        super.init(frame: .zero)

        let stackView = [
            UIView.spacer(height: 40),
            tokenIconImageView,
            UIView.spacer(height: 10),
            balanceLabel,
            UIView.spacer(height: 7),
            descriptionLabel,
            UIView.spacer(height: 20),
        ].asStackView(axis: .vertical, spacing: 0)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            tokenIconImageView.heightAnchor.constraint(equalToConstant: 60),

            //So the label doesn't "jump" when value goes from empty to non-empty
            balanceLabel.heightAnchor.constraint(equalToConstant: 45),

            stackView.anchorsConstraint(to: self),
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        balanceLabel.textAlignment = .center
        balanceLabel.textColor = .black
        balanceLabel.font = Fonts.regular(size: 36)

        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = R.color.dove()
        descriptionLabel.font = Fonts.regular(size: 17)
    }
}
