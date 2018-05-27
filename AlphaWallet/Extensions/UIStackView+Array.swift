// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

extension Array where Iterator.Element == UIView {
    public func asStackView(axis: UILayoutConstraintAxis = .horizontal, distribution: UIStackViewDistribution = .fill, spacing: CGFloat = 0, contentHuggingPriority: UILayoutPriority? = nil, perpendicularContentHuggingPriority: UILayoutPriority? = nil, alignment: UIStackViewAlignment = .fill) -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: self)
        stackView.axis = axis
        stackView.distribution = distribution
        stackView.alignment = alignment
        stackView.spacing = spacing
        if let contentHuggingPriority = contentHuggingPriority {
            switch axis {
            case .horizontal:
                stackView.setContentHuggingPriority(contentHuggingPriority, for: .horizontal)
            case .vertical:
                stackView.setContentHuggingPriority(contentHuggingPriority, for: .vertical)
            }
        }
        if let perpendicularContentHuggingPriority = perpendicularContentHuggingPriority {
            switch axis {
            case .horizontal:
                stackView.setContentHuggingPriority(perpendicularContentHuggingPriority, for: .vertical)
            case .vertical:
                stackView.setContentHuggingPriority(perpendicularContentHuggingPriority, for: .horizontal)
            }
        }
        return stackView
    }
}
