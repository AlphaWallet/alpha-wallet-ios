// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class BrowserHomeHeaderView: UIView {
    private let logoImage: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        return imageView
    }()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            logoImage,
            titleLabel,
        ].asStackView(axis: .vertical, spacing: 20, contentHuggingPriority: .required, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
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

    func configure(viewModel: BrowserHomeHeaderViewModel) {
        logoImage.image = viewModel.logo
        titleLabel.font = viewModel.titleFont
        titleLabel.text = viewModel.title
    }
}
