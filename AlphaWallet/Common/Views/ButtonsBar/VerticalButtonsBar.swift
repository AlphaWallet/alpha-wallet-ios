//
//  VerticalButtonsBar.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/3/22.
//

import UIKit

class VerticalButtonsBar: UIView, ButtonsBarViewType {
    var height: CGFloat {
        heightConstraint.constant
    }

    func observeButtonUpdates(closure: @escaping (_ sender: ButtonsBarViewType) -> Void) {
        guard observation == nil else { return }

        observation = observe(\.buttons) { [weak self] _, _ in
            guard let strongSelf = self else { return }

            closure(strongSelf)
        }
    }

    deinit {
        observation.flatMap { $0.invalidate() }
    }

    // MARK: - Properties

    // MARK: Private
    private lazy var heightConstraint: NSLayoutConstraint = {
        return NSLayoutConstraint(item: stackView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0.0)
    }()
    private lazy var stackView: UIStackView = UIStackView()
    private let maxButtonCount: Int
    private let spacing: CGFloat = 16.0
    private var buttonCount: Int = 0
    private var observation: NSKeyValueObservation?
    
    // MARK: Public
    @objc dynamic private (set) var buttons: [BarButton] = []

    // MARK: - Init

    init(numberOfButtons: Int) {
        buttonCount = numberOfButtons
        maxButtonCount = numberOfButtons
        super.init(frame: .zero)
        setup(numberOfButtons: numberOfButtons)
        adjustHeight()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public interface

    func hideButtonInStack(button: UIButton) {
        stackView.removeArrangedSubview(button)
        button.removeFromSuperview()
        buttonCount -= 1
        if buttonCount < 1 {
            buttonCount = 1
        }
        adjustHeight()
    }

    func showButtonInStack(button: UIButton, position: Int) {
        stackView.insertArrangedSubview(button, at: position)
        buttonCount += 1
        if buttonCount > maxButtonCount {
            buttonCount = maxButtonCount
        }
        adjustHeight()
    }

    // MARK: - Setup and creation
    private func setup(numberOfButtons: Int) {
        var buttonViews: [ContainerViewWithShadow<BarButton>] = [ContainerViewWithShadow<BarButton>]()
        guard numberOfButtons > 0 else { return }
        let primaryButton = createButton(viewModel: .primaryButton)
        primaryButton.childView.borderWidth = 0
        buttonViews.append(primaryButton)
        if numberOfButtons > 1 {
            (1 ..< numberOfButtons).forEach { _ in
                buttonViews.append(createButton(viewModel: .secondaryButton))
            }
        }
        setupStackView(views: buttonViews)
        setupButtons(views: buttonViews)
        setupView(numberOfButtons: numberOfButtons)
    }
    
    private func setupStackView(views: [UIView]) {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.removeAllArrangedSubviews()
        stackView.addArrangedSubviews(views)
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.spacing = 0.0
        addSubview(stackView)
        let margin = CGFloat(20)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
            heightConstraint,
        ])
    }

    private func setupButtons(views: [ContainerViewWithShadow<BarButton>]) {
        buttons.removeAll()
        views.forEach { view in
            buttons.append(view.childView)
        }
    }

    private func setupView(numberOfButtons: Int) {
        translatesAutoresizingMaskIntoConstraints = false
    }

    private func createButton(viewModel: ButtonsBarViewModel) -> ContainerViewWithShadow<BarButton> {
        let button = BarButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        let containerView = ContainerViewWithShadow(aroundView: button)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        setup(viewModel: viewModel, view: containerView)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50.0),
        ])
        return containerView
    }

    // TODO: This function duplicates a function in ButtonsBar. Merge these two functions.

    private func setup(viewModel: ButtonsBarViewModel, view: ContainerViewWithShadow<BarButton>) {
        view.configureShadow(color: viewModel.buttonShadowColor, offset: viewModel.buttonShadowOffset, opacity: viewModel.buttonShadowOpacity, radius: viewModel.buttonShadowRadius, cornerRadius: viewModel.buttonCornerRadius)

        let button = view.childView
        button.setBackgroundColor(viewModel.buttonBackgroundColor, forState: .normal)
        button.setBackgroundColor(viewModel.disabledButtonBackgroundColor, forState: .disabled)

        viewModel.highlightedButtonBackgroundColor.flatMap { button.setBackgroundColor($0, forState: .highlighted) }
        viewModel.highlightedButtonTitleColor.flatMap { button.setTitleColor($0, for: .highlighted) }

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

    // MARK: - Configuration

    private func adjustHeight() {
        let buttonsHeight = HorizontalButtonsBar.buttonsHeight * CGFloat(buttonCount)
        let spacingHeight = spacing * CGFloat(buttonCount - 1)
        heightConstraint.constant = buttonsHeight + spacingHeight
        // stackView.spacing = (buttonCount == 1) ? 0.0 : spacing
        setNeedsLayout()
    }
}
