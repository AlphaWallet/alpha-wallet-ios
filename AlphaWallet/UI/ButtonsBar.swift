// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

enum ButtonsBarConfiguration {
    case empty
    case combined(buttons: Int)
    case green(buttons: Int)
    case white(buttons: Int)
    case custom(types: [ButtonsBarButtonType])

    fileprivate static let maxCombinedButtons: Int = 2

    var buttonViewModels: [ButtonsBarButtonType] {
        switch self {
        case .green(let buttons):
            return (0..<buttons).compactMap { _ in .green }
        case .white(let buttons):
            return (0..<buttons).compactMap { _ in .white }
        case .custom(let types):
            return types
        case .combined(let buttons):
            let buttonsToShow: [ButtonsBarButtonType] = [.green, .white]
            if buttons > ButtonsBarConfiguration.maxCombinedButtons {
                return buttonsToShow
            } else {
                return [ButtonsBarButtonType](buttonsToShow.suffix(buttons))
            }
        case .empty:
            return []
        }
    }

    var showMoreButton: Bool {
        switch self {
        case .green, .white:
            return false
        case .custom:
            return false
        case .combined(let buttons):
            return buttons >= ButtonsBarConfiguration.maxCombinedButtons
        case .empty:
            return false
        }
    }
}

enum ButtonsBarButtonType {
    case green
    case white
}

struct MoreBarButtonViewModel {
    var title: String
    var isEnabled: Bool
}

protocol ButtonsBarDataSource: class {
    func buttonsBarNumberOfMoreActions(_ buttonsBar: ButtonsBar) -> Int
    func buttonsBar(_ buttonsBar: ButtonsBar, moreActionViewModelAtIndex index: Int) -> MoreBarButtonViewModel
}

protocol ButtonsBarDelegate: class {
    func buttonsBar(_ buttonsBar: ButtonsBar, didSelectMoreAction index: Int)
}

class ButtonsBar: UIView {
    static let buttonsHeight = CGFloat(48)
    //A gap so it doesn't stick to the bottom of devices without a bottom safe area
    static let marginAtBottomScreen = CGFloat(3)

    private var buttonContainerViews: [ContainerViewWithShadow<UIButton>] = []
    private var moreButtonContainerViews: [ContainerViewWithShadow<UIButton>] = []
    private let buttonsStackView: UIStackView
    private var innerStackView: UIStackView

    var buttons: [UIButton] {
        return buttonContainerViews.map { $0.childView }
    }

    var moreButtons: [UIButton] {
        return moreButtonContainerViews.map { $0.childView }
    }

    var isEmpty: Bool {
        return configuration.buttonViewModels.isEmpty
    }

    var configuration: ButtonsBarConfiguration = .empty {
        didSet {
            didUpdateView(with: configuration)
        }
    }

    weak var delegate: ButtonsBarDelegate?
    weak var dataSource: (ButtonsBarDataSource & UIViewController)?

    init(configuration: ButtonsBarConfiguration = .green(buttons: 1)) {
        buttonsStackView = [UIView]().asStackView(axis: .horizontal, distribution: .fillEqually, spacing: 7)
        innerStackView = [UIView]().asStackView(axis: .horizontal, distribution: .fill, spacing: 7)

        self.configuration = configuration
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        innerStackView.translatesAutoresizingMaskIntoConstraints = false

        innerStackView.addArrangedSubview(buttonsStackView)

        addSubview(innerStackView)

        let margin = CGFloat(20)
        NSLayoutConstraint.activate([
            innerStackView.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: margin, bottom: 0, right: margin)),
        ])

        didUpdateView(with: configuration)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func didUpdateView(with configuration: ButtonsBarConfiguration) {
        buttonContainerViews = ButtonsBar.bar(numberOfButtons: configuration.buttonViewModels.count)
        moreButtonContainerViews = ButtonsBar.bar(numberOfButtons: configuration.showMoreButton ? 1 : 0)

        for each in buttonsStackView.arrangedSubviews + innerStackView.arrangedSubviews {
            each.removeFromSuperview()
        }

        buttonsStackView.addArrangedSubviews(buttons)
        innerStackView.addArrangedSubviews([buttonsStackView] + moreButtons)
    }

    fileprivate func setup(viewModel: ButtonsBarViewModel, view: ContainerViewWithShadow<UIButton>) {
        view.configureShadow(color: viewModel.buttonShadowColor, offset: viewModel.buttonShadowOffset, opacity: viewModel.buttonShadowOpacity, radius: viewModel.buttonShadowRadius, cornerRadius: viewModel.buttonCornerRadius)

        let button = view.childView
        button.setBackgroundColor(viewModel.buttonBackgroundColor, forState: .normal)
        button.setBackgroundColor(viewModel.disabledButtonBackgroundColor, forState: .disabled)

        button.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        button.setTitleColor(viewModel.disabledButtonTitleColor, for: .disabled)

        button.titleLabel?.font = viewModel.buttonFont
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        //So long titles (that cause font to be adjusted) have some margins on the left and right
        button.contentEdgeInsets = .init(top: 0, left: 3, bottom: 0, right: 3)

        button.cornerRadius = viewModel.buttonCornerRadius
        button.borderColor = viewModel.buttonBorderColor
        button.borderWidth = viewModel.buttonBorderWidth
    }

    func configure(_ newConfiguration: ButtonsBarConfiguration? = nil) {
        if let newConfiguration = newConfiguration {
            configuration = newConfiguration
        }

        for (index, buttonType) in configuration.buttonViewModels.enumerated() {
            switch buttonType {
            case .green:
                setup(viewModel: .greenButton, view: buttonContainerViews[index])
            case .white:
                setup(viewModel: .whiteButton, view: buttonContainerViews[index])
            }
        }
        for view in moreButtonContainerViews {
             setup(viewModel: .moreButton, view: view)

             view.childView.setContentHuggingPriority(.required, for: .horizontal)
             view.childView.setContentCompressionResistancePriority(.required, for: .horizontal)
             view.childView.addTarget(self, action: #selector(optionsButtonTapped), for: .touchUpInside)
             view.childView.setBackgroundImage(R.image.more(), for: .normal)
         }
     }

    @objc private func optionsButtonTapped(sender: UIButton) {
        guard let dataSource = dataSource else { return }
        let actions = dataSource.buttonsBarNumberOfMoreActions(self)

        guard actions > 0 else { return }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.centerRect

        (0..<actions).forEach { index in
            let viewModel = dataSource.buttonsBar(self, moreActionViewModelAtIndex: index)
            let action = UIAlertAction(title: viewModel.title, style: .default) { _ in
                guard let delegate = self.delegate else { return }

                delegate.buttonsBar(self, didSelectMoreAction: index)
            }
            action.isEnabled = viewModel.isEnabled

            alertController.addAction(action)
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        alertController.addAction(cancelAction)

        dataSource.present(alertController, animated: true)
    }

    private static func bar(numberOfButtons: Int) -> [ContainerViewWithShadow<UIButton>] {
         return (0..<numberOfButtons).map { _ in
             let button = UIButton(type: .system)
             button.titleLabel?.baselineAdjustment = .alignCenters

             return ContainerViewWithShadow(aroundView: button)
         }
    }
}

private struct ButtonsBarViewModel {
    static let greenButton = ButtonsBarViewModel(
        buttonBackgroundColor: Colors.appActionButtonGreen,
        buttonTitleColor: Colors.appWhite,
        buttonBorderColor: Colors.appActionButtonGreen,
        buttonBorderWidth: 0
    )

    static let whiteButton = ButtonsBarViewModel()

    static let moreButton = ButtonsBarViewModel()

    var buttonBackgroundColor: UIColor = Colors.appWhite

    var disabledButtonBackgroundColor: UIColor {
        return Colors.disabledActionButton
    }

    var buttonTitleColor: UIColor = R.color.azure()!

    var disabledButtonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonCornerRadius: CGFloat {
        return ButtonsBar.buttonsHeight / 2.0
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
        return Fonts.semibold(size: 20)!
    }

    var buttonSecondaryBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var buttonSecondaryTitleColor: UIColor? {
        return nil
    }

    var buttonBorderColor: UIColor = R.color.azure()!

    var buttonBorderWidth: CGFloat = 1.0
}
