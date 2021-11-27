// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct TransactionAppearance {
    static func item(title: String, subTitle: String, icon: UIImage? = nil, completion:((_ title: String, _ value: String, _ sender: UIView) -> Void)? = .none) -> UIView {
        
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = Fonts.regular(size: 10)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Colors.headerThemeColor

        let subTitleLabel = UILabel(frame: .zero)
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.text = subTitle
        subTitleLabel.textAlignment = .left
        subTitleLabel.textColor = Colors.headerThemeColor
        subTitleLabel.font = Fonts.bold(size: 10)
        subTitleLabel.numberOfLines = 0

        let subTitleContainer = UIView(frame: .zero)
        subTitleContainer.translatesAutoresizingMaskIntoConstraints = false
        subTitleContainer.addSubview(subTitleLabel)
        
        let textLabelsStackView = [
            titleLabel,
        ].asStackView(axis: .vertical)
        
        textLabelsStackView.translatesAutoresizingMaskIntoConstraints = false
        textLabelsStackView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        textLabelsStackView.isLayoutMarginsRelativeArrangement = true
        var view: UIView
        
        if let icon = icon {
            let iconContainerView = UIView()
            iconContainerView.translatesAutoresizingMaskIntoConstraints = false
            iconContainerView.backgroundColor = .clear
            
            let iconImageView = UIImageView(image: icon)
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.contentMode = .scaleAspectFit
            
            iconContainerView.addSubview(iconImageView)
            let horizontalStack = [.spacerWidth(20), subTitleContainer, .spacerWidth(20), iconContainerView, .spacerWidth(20)].asStackView(axis: .horizontal)
            horizontalStack.translatesAutoresizingMaskIntoConstraints = false

            let verticalStackOuter = [.spacerWidth(9), horizontalStack, .spacerWidth(9)].asStackView(axis: .vertical)
            verticalStackOuter.translatesAutoresizingMaskIntoConstraints = false
            verticalStackOuter.cornerRadius = 8
            verticalStackOuter.borderWidth = 1
            verticalStackOuter.borderColor = Colors.appWhite
            
            let horizontalOuterView =  [.spacerWidth(20), verticalStackOuter, .spacerWidth(20)].asStackView(axis: .horizontal)
            horizontalOuterView.translatesAutoresizingMaskIntoConstraints = false

            let viewsToReturn = [textLabelsStackView, horizontalOuterView].asStackView(axis: .vertical, spacing: 8)
            
            NSLayoutConstraint.activate([
                iconContainerView.widthAnchor.constraint(equalToConstant: 24),
                iconContainerView.heightAnchor.constraint(equalToConstant: 44),
                subTitleContainer.heightAnchor.constraint(equalToConstant: 44),
                
                subTitleLabel.leadingAnchor.constraint(equalTo: subTitleContainer.leadingAnchor),
                subTitleLabel.trailingAnchor.constraint(equalTo: subTitleContainer.trailingAnchor),
                subTitleLabel.centerYAnchor.constraint(equalTo: subTitleContainer.centerYAnchor),
                
                iconImageView.leadingAnchor.constraint(equalTo: iconContainerView.leadingAnchor),
                iconImageView.trailingAnchor.constraint(equalTo: iconContainerView.trailingAnchor),
                iconImageView.centerYAnchor.constraint(equalTo: subTitleLabel.centerYAnchor)
            ])
            
            view = viewsToReturn
        } else {
            let horizontalStack = [.spacerWidth(20), subTitleLabel, .spacerWidth(20)].asStackView(axis: .horizontal)
            view = [textLabelsStackView, horizontalStack].asStackView(axis: .vertical, spacing: 5)
        }
        
        UITapGestureRecognizer(addToView: view) {
            completion?(title, subTitle, view)
        }

        return view
    }
}
