//
//  TokensTableHeaderView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 21.07.2020.
//

import UIKit

struct TokensTableHeaderViewModel {
    let title: String

    var titleAttributedString: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.lineSpacing = ScreenChecker().isNarrowScreen ? 7 : 41

        return NSAttributedString(string: title, attributes: [
            .paragraphStyle: style,
            .font: Fonts.bold(size: 24)!,
            .foregroundColor: R.color.black()!,
        ])
    }
}

extension TokensViewController {

    class TokensTableHeaderView: UITableViewHeaderFooterView {

        private lazy var titleLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false

            return label
        }()

        private lazy var separatorView: UIView = {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = R.color.mercury()
            return view
        }()

        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            backgroundColor = Colors.appWhite
            contentView.backgroundColor = Colors.appWhite

            addSubview(titleLabel)
            addSubview(separatorView)

            NSLayoutConstraint.activate([
                titleLabel.anchorsConstraint(to: self, edgeInsets: .init(top: 16, left: 16, bottom: 8, right: 16)),
                separatorView.bottomAnchor.constraint(equalTo: bottomAnchor),
                separatorView.leadingAnchor.constraint(equalTo: leadingAnchor),
                separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
                separatorView.heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight)
            ])
        }

        required init?(coder aDecoder: NSCoder) {
            return nil
        }

        func configure(viewModel: TokensTableHeaderViewModel) {
            titleLabel.attributedText = viewModel.titleAttributedString
        }
    }
}
