// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class ButtonsBar: UIView {
    static let buttonsHeight = CGFloat(48)
    //A gap so it doesn't stick to the bottom of devices without a bottom safe area
    static let marginAtBottomScreen = CGFloat(3)

    private var buttonContainerViews: [ContainerViewWithShadow<UIButton>]
    private let buttonsStackView: UIStackView

    var numberOfButtons: Int {
        didSet {
            buttonContainerViews = ButtonsBar.bar(numberOfButtons: numberOfButtons)
            for each in buttonsStackView.arrangedSubviews {
                each.removeFromSuperview()
            }
            buttonsStackView.addArrangedSubviews(buttons)
        }
    }

    var buttons: [UIButton] {
        return buttonContainerViews.map { $0.childView }
    }

    var isEmpty: Bool {
        return numberOfButtons == 0
    }

    init(numberOfButtons: Int, buttonsDistribution: UIStackView.Distribution = .fillEqually) {
        self.numberOfButtons = numberOfButtons
        buttonsStackView =  [UIView]().asStackView(axis: .horizontal, distribution: buttonsDistribution, spacing: 7)
        buttonContainerViews = ButtonsBar.bar(numberOfButtons: numberOfButtons)

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        buttonsStackView.addArrangedSubviews(buttons)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttonsStackView)

        let margin = CGFloat(20)
        NSLayoutConstraint.activate([
            buttonsStackView.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: margin, bottom: 0, right: margin)),
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
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            //So long titles (that cause font to be adjusted) have some margins on the left and right
            button.contentEdgeInsets = .init(top: 0, left: 3, bottom: 0, right: 3)
        }
    }

    func configureSecondary() {
        let viewModel = ButtonsBarViewModel()

        for each in buttonContainerViews {
            each.configureShadow(color: viewModel.buttonShadowColor, offset: viewModel.buttonShadowOffset, opacity: viewModel.buttonShadowOpacity, radius: viewModel.buttonShadowRadius, cornerRadius: viewModel.buttonCornerRadius)

            let button = each.childView
            button.setBackgroundColor(viewModel.buttonSecondaryBackgroundColor, forState: .normal)
            button.setBackgroundColor(viewModel.disabledButtonBackgroundColor, forState: .disabled)
            button.setTitleColor(viewModel.buttonSecondaryTitleColor, for: .normal)
            button.setTitleColor(viewModel.disabledButtonTitleColor, for: .disabled)
            button.titleLabel?.font = viewModel.buttonFont
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            //So long titles (that cause font to be adjusted) have some margins on the left and right
            button.contentEdgeInsets = .init(top: 0, left: 3, bottom: 0, right: 3)

            button.cornerRadius = viewModel.buttonSecondaryCornerRadius
            button.borderColor = viewModel.buttonSecondaryBorderColor
            button.borderWidth = viewModel.buttonSecondaryBorderWidth
        }
    }

    private static func bar(numberOfButtons: Int) -> [ContainerViewWithShadow<UIButton>] {
        return (0..<numberOfButtons).map { _ in ContainerViewWithShadow(aroundView: UIButton(type: .system)) }
    }
}

private struct ButtonsBarViewModel {
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
        return 4
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
        return 2
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var buttonSecondaryBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var buttonSecondaryTitleColor: UIColor? {
        return nil
    }

    var buttonSecondaryCornerRadius: CGFloat {
        return 4
    }

    var buttonSecondaryBorderColor: UIColor {
        return .init(red: 202, green: 202, blue: 202)
    }

    var buttonSecondaryBorderWidth: CGFloat {
        return 1
    }
}
