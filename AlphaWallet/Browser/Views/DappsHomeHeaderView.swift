// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class DappsHomeHeaderView: UIView {
    private let stackView = [].asStackView(axis: .vertical, contentHuggingPriority: .required, alignment: .center)
    private let logoImage = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubviews([
            logoImage,
            .spacer(height: 20),
            titleLabel,
        ])
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            logoImage.widthAnchor.constraint(equalToConstant: 80),
            logoImage.widthAnchor.constraint(equalTo: logoImage.heightAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DappsHomeHeaderViewViewModel) {
        backgroundColor = viewModel.backgroundColor

        logoImage.contentMode = .scaleAspectFit
        logoImage.image = viewModel.logo

        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title
    }
}
