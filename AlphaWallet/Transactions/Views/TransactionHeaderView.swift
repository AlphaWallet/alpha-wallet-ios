// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

class TransactionHeaderView: UIView {
    private let server: RPCServer
    
    private let titleLabel = UILabel(frame: .zero)
    private let subTitleLabel = UILabel(frame: .zero)
    
    init(server: RPCServer) {
        self.server = server
        super.init(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Fonts.regular(size: 10)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Colors.headerThemeColor

        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.textAlignment = .left
        subTitleLabel.textColor = Colors.headerThemeColor
        subTitleLabel.font = Fonts.bold(size: 10)
        subTitleLabel.numberOfLines = 0
        
        let textLabelsStackView = [
            titleLabel,
        ].asStackView(axis: .vertical)
        
        let subTitleContainer = UIView(frame: .zero)
        subTitleContainer.translatesAutoresizingMaskIntoConstraints = false
        subTitleContainer.addSubview(subTitleLabel)
        
        let horizontalStack = [.spacerWidth(20), subTitleContainer, .spacerWidth(20)].asStackView(axis: .horizontal)
        horizontalStack.translatesAutoresizingMaskIntoConstraints = false

        let verticalStackOuter = [.spacerWidth(9), horizontalStack, .spacerWidth(9)].asStackView(axis: .vertical)
        verticalStackOuter.translatesAutoresizingMaskIntoConstraints = false
        verticalStackOuter.cornerRadius = 8
        verticalStackOuter.borderWidth = 1
        verticalStackOuter.borderColor = Colors.appWhite
        
        let horizontalOuterView =  [.spacerWidth(20), verticalStackOuter, .spacerWidth(20)].asStackView(axis: .horizontal)
        horizontalOuterView.translatesAutoresizingMaskIntoConstraints = false
        
        let textLabelsHorizontalStack = [.spacerWidth(20), textLabelsStackView, .spacerWidth(20)].asStackView(axis: .horizontal)

        let viewsToReturn = [textLabelsHorizontalStack, horizontalOuterView].asStackView(axis: .vertical, spacing: 8)
        viewsToReturn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(viewsToReturn)

        NSLayoutConstraint.activate([
            subTitleContainer.heightAnchor.constraint(equalToConstant: 44),
            subTitleLabel.leadingAnchor.constraint(equalTo: subTitleContainer.leadingAnchor),
            subTitleLabel.trailingAnchor.constraint(equalTo: subTitleContainer.trailingAnchor),
            subTitleLabel.centerYAnchor.constraint(equalTo: subTitleContainer.centerYAnchor),
            viewsToReturn.topAnchor.constraint(equalTo: topAnchor),
            viewsToReturn.trailingAnchor.constraint(equalTo: trailingAnchor),
            viewsToReturn.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            viewsToReturn.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(amount: NSAttributedString) {
        subTitleLabel.attributedText = amount
        titleLabel.text = "Value"
    }
}
