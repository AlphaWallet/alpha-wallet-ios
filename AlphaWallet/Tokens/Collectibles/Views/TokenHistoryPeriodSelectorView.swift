//
//  TokenHistoryPeriodSelectorView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit

protocol TokenHistoryPeriodSelectorViewDelegate: AnyObject {
    func view(_ view: TokenHistoryPeriodSelectorView, didChangeSelection selection: ControlSelection)
}

struct TokenHistoryPeriodSelectorViewModel {
    var titles: [String]
    let selectedStateBackgroundColor: UIColor = Configuration.Color.Semantic.periodButtonSelectedBackground
    let normalStateBackgroundColor: UIColor = Configuration.Color.Semantic.periodButtonNormalBackground

    let selectedStateTextColor: UIColor = Configuration.Color.Semantic.periodButtonSelectedText
    let normalStateTextColor: UIColor = Configuration.Color.Semantic.periodButtonNormalText
}

class TokenHistoryPeriodSelectorView: UIView {
    private let controls: [UIButton]
    private var backgrounds: [ButtonBackgroundView] = [ButtonBackgroundView]()

    var selectedIndex: ControlSelection {
        if let index = controls.firstIndex(where: { $0.isSelected }) {
            return .selected(UInt(index))
        } else {
            return .unselected
        }
    }

    weak var delegate: TokenHistoryPeriodSelectorViewDelegate?

    init(viewModel: TokenHistoryPeriodSelectorViewModel) {
        controls = viewModel.titles.enumerated().map { value -> UIButton in
            let button = UIButton(type: .custom)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle(value.element, for: .normal)
            button.tag = value.offset
            button.setTitleColor(viewModel.selectedStateTextColor, for: .selected)
            button.setTitleColor(viewModel.normalStateTextColor, for: .normal)
            button.tintColor = .clear
            button.adjustsImageWhenHighlighted = false
            button.layer.cornerRadius = 5
            button.clipsToBounds = true
            button.isHighlighted = false
            button.isSelected = false
            return button
        }

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let views = controls.map { button -> UIView in
            let view = ButtonBackgroundView(viewModel: viewModel, button: button)
            view.translatesAutoresizingMaskIntoConstraints = false
            backgrounds.append(view)
            button.addTarget(self, action: #selector(controlSelected), for: .touchUpInside)
            view.addSubview(button)
            NSLayoutConstraint.activate(
                view.anchorsConstraint(to: button)
            )
            return view as UIView
        }
        let stackView = views.asStackView(axis: .horizontal, distribution: .fillEqually, spacing: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: .init(top: 10, left: 30, bottom: 10, right: 30)),
            heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func set(selectedIndex: Int) {
        let sender = controls[selectedIndex]
        updateControlsSelectionState(selection: sender)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func controlSelected(_ sender: UIButton) {
        updateControlsSelectionState(selection: sender)
        delegate?.view(self, didChangeSelection: selectedIndex)
    }

    private func updateControlsSelectionState(selection: UIButton) {
        for control in controls {
            control.isSelected = control == selection
        }
        for background in backgrounds {
            background.setState(via: selection)
        }
    }
}

fileprivate class ButtonBackgroundView: UIView {
    private enum ButtonState {
        case selected
        case normal
    }
    private var state: ButtonState = .normal {
        didSet {
            if state != oldValue {
                updateBackground()
            }
        }
    }
    private let viewModel: TokenHistoryPeriodSelectorViewModel
    private let button: UIButton

    init(viewModel: TokenHistoryPeriodSelectorViewModel, button: UIButton) {
        self.viewModel = viewModel
        self.button = button
        super.init(frame: .zero)
        updateBackground()
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 5
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func updateBackground() {
        switch state {
        case .selected:
            backgroundColor = viewModel.selectedStateBackgroundColor
        case .normal:
            backgroundColor = viewModel.normalStateBackgroundColor
        }
    }

    func setState(via button: UIButton) {
        if self.button == button {
            state = .selected
        } else {
            state = .normal
        }
    }

}
