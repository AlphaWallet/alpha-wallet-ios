//
//  TokenInfoHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit

struct TokenInfoHeaderViewModel {
    private let title: String

    init(title: String) {
        self.title = title
    }

    var attributedTitle: NSAttributedString {
        return .init(string: title, attributes: [
            .font: Fonts.bold(size: 24),
            .foregroundColor: Colors.black
        ])
    }
}

class TokenInfoHeaderView: UIView {

    private let label: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.anchorsConstraint(to: self, edgeInsets: .init(top: 15, left: 10, bottom: 20, right: 0))
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: TokenInfoHeaderViewModel) {
        label.attributedText = viewModel.attributedTitle
    }
}
