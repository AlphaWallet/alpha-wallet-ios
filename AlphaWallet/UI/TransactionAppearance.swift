// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

struct TransactionAppearance {
    static func item(title: String, subTitle: String, icon: UIImage? = nil, completion:((_ title: String, _ value: String, _ sender: UIView) -> Void)? = .none) -> UIView {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = Fonts.regular(size: 18)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Colors.darkGray

        let subTitleLabel = UILabel(frame: .zero)
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.text = subTitle
        subTitleLabel.textAlignment = .left
        subTitleLabel.textColor = Colors.black
        subTitleLabel.font = Fonts.light(size: 15)
        subTitleLabel.numberOfLines = 0

        let textLabelsStackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical, spacing: 10)
        
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
            
            let viewsToReturn = [textLabelsStackView, iconContainerView, .spacerWidth(20)].asStackView(axis: .horizontal)
            
            NSLayoutConstraint.activate([
                iconContainerView.widthAnchor.constraint(equalToConstant: 24),
                iconImageView.leadingAnchor.constraint(equalTo: iconContainerView.leadingAnchor),
                iconImageView.trailingAnchor.constraint(equalTo: iconContainerView.trailingAnchor),
                iconImageView.centerYAnchor.constraint(equalTo: subTitleLabel.centerYAnchor)
            ])
            
            view = viewsToReturn
        } else {
            view = textLabelsStackView
        }
        
        UITapGestureRecognizer(addToView: view) {
            completion?(title, subTitle, view)
        }

        return view
    }
}
