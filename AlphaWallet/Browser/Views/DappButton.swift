// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class DappButton: UIControl {

    private let imageView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let stackView = [imageView, label].asStackView(
                axis: .vertical,
                contentHuggingPriority: .required,
                alignment: .center
        )
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isUserInteractionEnabled = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 50),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DappButtonViewModel) {
        imageView.image = viewModel.image

        label.font = viewModel.font
        label.textColor = viewModel.textColor
        label.text = viewModel.title
    }
}
