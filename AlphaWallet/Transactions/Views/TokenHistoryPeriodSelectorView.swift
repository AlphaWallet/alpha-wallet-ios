//
//  TokenHistoryPeriodSelectorView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit

protocol TokenHistoryPeriodSelectorViewDelegate: class {
    func view(_ view: TokenHistoryPeriodSelectorView, didChangeSelection selection: SegmentedControl.Selection)
}

struct TokenHistoryPeriodSelectorViewModel {
    var titles: [String]
    var selectedStateBackgroundColor: UIColor = Colors.darkGray
    var normalStateBackgroundColor: UIColor = .white

    var selectedStateTextColor: UIColor = .white
    var normalStateTextColor: UIColor = Colors.darkGray
}

class TokenHistoryPeriodSelectorView: UIView {
    private let controls: [UIButton]

    var selectedIndex: SegmentedControl.Selection {
        if let index = controls.firstIndex(where: { $0.isSelected }) {
            return .selected(UInt(index))
        } else {
            return .unselected
        }
    }

    weak var delegate: TokenHistoryPeriodSelectorViewDelegate?

    init(viewModel: TokenHistoryPeriodSelectorViewModel) {
        controls = viewModel.titles.enumerated().map { value -> UIButton in
            let button = UIButton(type: .system)
            button.setTitle(value.element, for: .normal)
            button.tag = value.offset

            button.setTitleColor(viewModel.selectedStateTextColor, for: .selected)
            button.setTitleColor(viewModel.selectedStateTextColor, for: .highlighted)
            button.setTitleColor(viewModel.normalStateTextColor, for: .normal)

            button.setBackgroundColor(viewModel.selectedStateBackgroundColor, forState: .selected)
            button.setBackgroundColor(viewModel.selectedStateBackgroundColor, forState: .highlighted)
            button.setBackgroundColor(viewModel.normalStateBackgroundColor, forState: .normal)

            button.layer.cornerRadius = 5
            button.clipsToBounds = true

            return button
        }

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        controls.forEach { button in
            button.addTarget(self, action: #selector(controlSelected), for: .touchUpInside)
        }

        let views = controls.map { $0 as UIView }
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
    }
}
