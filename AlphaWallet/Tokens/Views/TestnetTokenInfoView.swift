//
//  TestnetTokenInfoView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.12.2021.
//

import UIKit

struct TestnetTokenInfoViewModel {
    var attributedText: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = ScreenChecker().isNarrowScreen ? 6 : 12
        
        return .init(string: R.string.localizable.tokenTestnetWarning(), attributes: [
            .font: Fonts.italic(size: 17),
            .foregroundColor: R.color.dove()!,
            .paragraphStyle: style
        ])
    }
}

class TestnetTokenInfoView: UIView {

    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        return label
    }()

    init(edgeInsets: UIEdgeInsets = .init(top: 62, left: 35, bottom: 0, right: 35)) {
        super.init(frame: .zero)
        addSubview(textLabel)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textLabel.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: TestnetTokenInfoViewModel) {
        textLabel.attributedText = viewModel.attributedText
    }
}
