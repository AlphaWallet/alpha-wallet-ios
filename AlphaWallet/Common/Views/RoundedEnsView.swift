//
//  RoundedEnsView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.11.2022.
//

import UIKit
import Combine

class RoundedEnsView: UIView, ViewRoundingSupportable {
    private (set) lazy var label: UILabel = {
        let label = UILabel(frame: .zero)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)

        return label
    }()

    private (set) var copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(R.image.copy(), for: .normal)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 30)
        ])

        return button
    }()

    var tapPublisher: AnyPublisher<Void, Never> {
        return Publishers.Merge(
            copyButton.publisher(forEvent: .touchUpInside).mapToVoid(),
            publisher(for: UITapGestureRecognizer()).mapToVoid()
        ).eraseToAnyPublisher()
    }

    var rounding: ViewRounding = .none {
        didSet { layoutSubviews() }
    }
    var placeholderRounding: ViewRounding = .none

    init(viewModel: RoundedEnsViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [.spacerWidth(7), label, .spacerWidth(10), copyButton, .spacerWidth(7)].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        let edgeInsets = UIEdgeInsets(
            top: ScreenChecker.size(big: 14, medium: 12, small: 10),
            left: ScreenChecker.size(big: 20, medium: 18, small: 15),
            bottom: ScreenChecker.size(big: 14, medium: 12, small: 10),
            right: ScreenChecker.size(big: 20, medium: 18, small: 15))

        NSLayoutConstraint.activate([
            //Leading/trailing anchor needed to make label fit when on narrow iPhones
            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])

        isUserInteractionEnabled = true

        configure(viewModel: viewModel)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.masksToBounds = true
        clipsToBounds = true

        cornerRadius = rounding.cornerRadius(view: self)
    }

    func configure(viewModel: RoundedEnsViewModel) {
        isHidden = viewModel.isHidden
        rounding = .circle
        label.text = viewModel.text
        label.font = viewModel.labelFont
        label.textColor = viewModel.labelTextColor
        backgroundColor = viewModel.backgroundColor
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
