// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class ButtonsBar: UIView {
    static let buttonsHeight = CGFloat(48)
    //A gap so it doesn't stick to the bottom of devices without a bottom safe area
    static let marginAtBottomScreen = CGFloat(3)

    private let buttonContainerViews: [ContainerViewWithShadow<UIButton>]

    var buttons: [UIButton] {
        return buttonContainerViews.map { $0.childView }
    }

    init(numberOfButtons: Int, buttonsDistribution: UIStackView.Distribution = .fillEqually) {
        buttonContainerViews = (0..<numberOfButtons).map { _ in ContainerViewWithShadow(aroundView: UIButton(type: .system)) }

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let buttonsStackView = (buttons as [UIView]).asStackView(axis: .horizontal, distribution: buttonsDistribution, spacing: 7)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonsStackView)

        let margin = CGFloat(20)
        NSLayoutConstraint.activate([
            buttonsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            buttonsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
            buttonsStackView.topAnchor.constraint(equalTo: topAnchor),
            buttonsStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        let viewModel = ButtonsBarViewModel()

        for each in buttonContainerViews {
            each.configureShadow(color: viewModel.buttonShadowColor, offset: viewModel.buttonShadowOffset, opacity: viewModel.buttonShadowOpacity, radius: viewModel.buttonShadowRadius, cornerRadius: viewModel.buttonCornerRadius)

            let button = each.childView
            button.setBackgroundColor(viewModel.buttonBackgroundColor, forState: .normal)
            button.setBackgroundColor(viewModel.disabledButtonBackgroundColor, forState: .disabled)
            button.setTitleColor(viewModel.buttonTitleColor, for: .normal)
            button.setTitleColor(viewModel.disabledButtonTitleColor, for: .disabled)
            button.titleLabel?.font = viewModel.buttonFont
        }
    }
}

fileprivate struct ButtonsBarViewModel {
    var buttonBackgroundColor: UIColor {
        return Colors.appActionButtonGreen
    }

    var disabledButtonBackgroundColor: UIColor {
        return Colors.gray
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var disabledButtonTitleColor: UIColor {
        return Colors.darkGray
    }

    var buttonCornerRadius: CGFloat {
        return 16
    }

    var buttonShadowColor: UIColor {
        return Colors.appActionButtonShadow
    }

    var buttonShadowOffset: CGSize {
        return .init(width: 1, height: 2)
    }

    var buttonShadowOpacity: Float {
        return 0.3
    }

    var buttonShadowRadius: CGFloat {
        return 5
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }
}
