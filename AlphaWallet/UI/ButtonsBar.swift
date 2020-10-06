// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

enum ButtonsBarConfiguration {
    case empty
    case combined(buttons: Int)
    case green(buttons: Int)
    case white(buttons: Int)
    case custom(types: [ButtonsBarButtonType])

    static let maxCombinedButtons: Int = 2

    var barButtonTypes: [ButtonsBarButtonType] {
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
                let hiddenButtonsCount = buttons - buttonsToShow.count

                return buttonsToShow + [ButtonsBarButtonType].init(repeating: .white, count: hiddenButtonsCount)
            } else {
                return [ButtonsBarButtonType](buttonsToShow.prefix(buttons))
            }
        case .empty:
            return []
        }
    }

    func shouldHideButton(at index: Int) -> Bool {
        switch self {
        case .green, .white:
            return false
        case .custom:
            return false
        case .combined(let buttons):
            return buttons >= ButtonsBarConfiguration.maxCombinedButtons && index >= ButtonsBarConfiguration.maxCombinedButtons
        case .empty:
            return false
        }
    }

    var showMoreButton: Bool {
        switch self {
        case .green, .white:
            return false
        case .custom:
            return false
        case .combined(let buttons):
            return buttons > ButtonsBarConfiguration.maxCombinedButtons
        case .empty:
            return false
        }
    }
}

enum ButtonsBarButtonType {
    case green
    case white
}

class BarButton: UIButton {

    private var observation: NSKeyValueObservation?
    private var borderColorMap: [UInt: UIColor?] = [:]
    @objc dynamic var displayButton: Bool = true

    init() {
        super.init(frame: .zero)
        self.observation = observe(\.isEnabled, options: [.old, .new]) { [weak self] object, change in
            guard let strongSelf = self else { return }

            for pair in strongSelf.borderColorMap where pair.key == object.state.rawValue {
                strongSelf.layer.borderColor = pair.value?.cgColor
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setBorderColor(_ color: UIColor?, for state: UIControl.State) {
        borderColorMap[state.rawValue] = color
    }
}

class ButtonsBarBackgroundView: UIView {

    private let buttonsBar: ButtonsBar
    private let separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.mike()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var observation: NSKeyValueObservation?

    init(buttonsBar: ButtonsBar, edgeInsets: UIEdgeInsets = DataEntry.Metric.ButtonsBar.insets) {
        self.buttonsBar = buttonsBar
        super.init(frame: .zero)

        addSubview(separatorLine)
        addSubview(buttonsBar)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Colors.appWhite

        NSLayoutConstraint.activate([
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorLine.topAnchor.constraint(equalTo: topAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: DataEntry.Metric.ButtonsBar.separatorHeight),

            buttonsBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: edgeInsets.left),
            buttonsBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -edgeInsets.right),
            buttonsBar.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: edgeInsets.top),
            buttonsBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -edgeInsets.bottom),
        ])

        observation = buttonsBar.observe(\.buttons) { sender, _ in
            self.isHidden = sender.buttons.isEmpty
        }
    }

    func anchorsConstraint(to view: UIView) -> [NSLayoutConstraint] {
        return [
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

class ButtonsBar: UIView {
    static let buttonsHeight = CGFloat(ScreenChecker().isNarrowScreen ? 38 : 48)
    //A gap so it doesn't stick to the bottom of devices without a bottom safe area
    static let marginAtBottomScreen = CGFloat(3)

    private var buttonContainerViews: [ContainerViewWithShadow<BarButton>] = []
    private var moreButtonContainerViews: [ContainerViewWithShadow<BarButton>] = []
    //NOTE: we need to handle buttont changes, for this we will use buttonsStackView, to make sure that number of button has changed
    private var buttonsStackView: UIStackView
    private var innerStackView: UIStackView
    private var observations: [NSKeyValueObservation] = []

    private var visibleButtons: [BarButton] {
        buttons.filter { $0.displayButton }.enumerated().filter { configuration.shouldHideButton(at: $0.offset) }.map { $0.element }
    }

    @objc dynamic var buttons: [BarButton] {
        return buttonContainerViews.map { $0.childView }
    }

    var moreButtons: [BarButton] {
        return moreButtonContainerViews.map { $0.childView }
    }

    var isEmpty: Bool {
        return configuration.barButtonTypes.isEmpty
    }

    var configuration: ButtonsBarConfiguration = .empty {
        didSet {
            didUpdateView(with: configuration)
        }
    }

    weak var viewController: UIViewController?

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
            heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),
            innerStackView.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: margin, bottom: 0, right: margin)),
        ])

        didUpdateView(with: configuration)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func didUpdateView(with configuration: ButtonsBarConfiguration) {
        willChangeValue(for: \.buttons)

        buttonContainerViews = ButtonsBar.bar(numberOfButtons: configuration.barButtonTypes.count)
        resetIsHiddenObservers()

        for view in buttonContainerViews {
            let observation = view.childView.observe(\.displayButton, options: [.new]) { [weak self] object, change in
                self?.updateButtonsTypes()
            }
            observations.append(observation)
        }

        moreButtonContainerViews = ButtonsBar.bar(numberOfButtons: configuration.showMoreButton ? 1 : 0)

        for each in buttonsStackView.arrangedSubviews + innerStackView.arrangedSubviews {
            each.removeFromSuperview()
        }

        buttonsStackView.addArrangedSubviews(buttons)
        innerStackView.addArrangedSubviews([buttonsStackView] + moreButtons)

        didChangeValue(for: \.buttons)
    }

    fileprivate func setup(viewModel: ButtonsBarViewModel, view: ContainerViewWithShadow<BarButton>) {
        view.configureShadow(color: viewModel.buttonShadowColor, offset: viewModel.buttonShadowOffset, opacity: viewModel.buttonShadowOpacity, radius: viewModel.buttonShadowRadius, cornerRadius: viewModel.buttonCornerRadius)

        let button = view.childView
        button.setBackgroundColor(viewModel.buttonBackgroundColor, forState: .normal)
        button.setBackgroundColor(viewModel.disabledButtonBackgroundColor, forState: .disabled)

        button.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        button.setTitleColor(viewModel.disabledButtonTitleColor, for: .disabled)
        button.setBorderColor(viewModel.buttonBorderColor, for: .normal)
        button.setBorderColor(viewModel.disabledButtonBorderColor, for: .disabled)
        button.titleLabel?.font = viewModel.buttonFont
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        //So long titles (that cause font to be adjusted) have some margins on the left and right
        button.contentEdgeInsets = .init(top: 0, left: 3, bottom: 0, right: 3)

        button.cornerRadius = viewModel.buttonCornerRadius
        button.borderColor = viewModel.buttonBorderColor
        button.borderWidth = viewModel.buttonBorderWidth
    }

    private func resetIsHiddenObservers() {
        observations.forEach {
            $0.invalidate()
        }
        observations.removeAll()
    }

    func configure(_ newConfiguration: ButtonsBarConfiguration? = nil) {
        if let newConfiguration = newConfiguration {
            configuration = newConfiguration
        }

        updateButtonsTypes()

        for view in moreButtonContainerViews {
            setup(viewModel: .moreButton, view: view)

            view.childView.setContentHuggingPriority(.required, for: .horizontal)
            view.childView.setContentCompressionResistancePriority(.required, for: .horizontal)
            view.childView.addTarget(self, action: #selector(optionsButtonTapped), for: .touchUpInside)
            view.childView.setBackgroundImage(R.image.more(), for: .normal)

            NSLayoutConstraint.activate([
                view.childView.widthAnchor.constraint(equalTo: view.childView.heightAnchor)
            ])
        }
    }

    private func updateButtonsTypes() {
        let viewsToDisplay = buttonContainerViews.filter { $0.childView.displayButton }

        for (index, combined) in zip(configuration.barButtonTypes, viewsToDisplay).enumerated() {
            combined.1.childView.isHidden = configuration.shouldHideButton(at: index)

            switch combined.0 {
            case .green:
                setup(viewModel: .greenButton, view: combined.1)
            case .white:
                setup(viewModel: .whiteButton, view: combined.1)
            }
        }

        for view in buttonContainerViews.filter({ !$0.childView.displayButton }) {
            view.childView.isHidden = true
        }
    }

    @objc private func optionsButtonTapped(sender: BarButton) {
        let buttons = visibleButtons
        guard buttons.isEmpty == false else { return }

        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.centerRect

        for (i, button) in buttons.enumerated() {
            guard let title = button.title(for: .normal) else { continue }

            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let strongSelf = self else { return }
                let buttons = strongSelf.visibleButtons
                let actualButton: UIButton
                if i < buttons.count {
                    //This sequence of event is possible and common, so we have to figure out the button in the current set of buttons after refresh:
                    //1. Tap more button to show action sheet
                    //2. UI refreshes and buttons B are replaced with B'
                    //3. User tap button X in action sheet
                    //4. We use B to send the action, which is no longer there. We need to find B' instead
                    //A problem with this approach is if the actions has changed in terms of order or number, the wrong action might be chosen
                    //TODO close actionsheet if actions are different from before?
                    actualButton = buttons[i]
                } else {
                    actualButton = button
                }
                actualButton.sendActions(for: .touchUpInside)
            }
            action.isEnabled = button.isEnabled

            alertController.addAction(action)
        }

        let cancelAction = UIAlertAction(title: R.string.localizable.cancel(), style: .cancel) { _ in }
        alertController.addAction(cancelAction)

        viewController?.present(alertController, animated: true)
    }

    private static func bar(numberOfButtons: Int) -> [ContainerViewWithShadow<BarButton>] {
         return (0..<numberOfButtons).map { _ in
             let button = BarButton()
             button.titleLabel?.baselineAdjustment = .alignCenters

             return ContainerViewWithShadow(aroundView: button)
         }
    }
}

private struct ButtonsBarViewModel {

    static let greenButton = ButtonsBarViewModel(
        buttonBackgroundColor: Colors.appActionButtonGreen,
        disabledButtonBackgroundColor: Colors.appActionButtonGreen.withAlphaComponent(0.3),
        disabledButtonBorderColor: Colors.appActionButtonGreen,
        buttonTitleColor: Colors.appWhite,
        buttonBorderColor: Colors.appActionButtonGreen,
        buttonBorderWidth: 0
    )

    static let whiteButton = ButtonsBarViewModel(
        buttonBackgroundColor: Colors.appWhite,
        disabledButtonBackgroundColor: Colors.appWhite,
        disabledButtonBorderColor: R.color.azure()!.withAlphaComponent(0.3),
        disabledButtonTitleColor: R.color.azure()!.withAlphaComponent(0.3)
    )

    static let moreButton = ButtonsBarViewModel()

    var buttonBackgroundColor: UIColor = Colors.appWhite

    var disabledButtonBackgroundColor: UIColor = Colors.disabledActionButton
    var disabledButtonBorderColor: UIColor = Colors.disabledActionButton

    var buttonTitleColor: UIColor = R.color.azure()!

    var disabledButtonTitleColor: UIColor = Colors.appWhite

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
        return Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 16 : 20)!
    }

    var buttonBorderColor: UIColor = R.color.azure()!

    var buttonBorderWidth: CGFloat = 1.0
}
