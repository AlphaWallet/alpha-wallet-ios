//
//  ButtonsBarBackgroundView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

class ButtonsBarBackgroundView: UIView {

    private let buttonsBar: ButtonsBarViewType
    private let separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.mike()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var observation: NSKeyValueObservation?
    private let edgeInsets: UIEdgeInsets

    var height: CGFloat {
        self.buttonsBar.height + edgeInsets.top + edgeInsets.bottom + UIApplication.shared.bottomSafeAreaHeight
    }

    init(buttonsBar: ButtonsBarViewType, edgeInsets: UIEdgeInsets = DataEntry.Metric.ButtonsBar.insets, separatorHeight: CGFloat = DataEntry.Metric.ButtonsBar.separatorHeight) {
        self.buttonsBar = buttonsBar
        self.edgeInsets = edgeInsets
        super.init(frame: .zero)

        addSubview(separatorLine)
        addSubview(buttonsBar)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = Colors.appWhite

        NSLayoutConstraint.activate([
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorLine.topAnchor.constraint(equalTo: topAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: separatorHeight),

            buttonsBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: edgeInsets.left),
            buttonsBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -edgeInsets.right),
            buttonsBar.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: edgeInsets.top),
            buttonsBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -edgeInsets.bottom),
        ])

        buttonsBar.observeButtonUpdates { [weak self] sender in
            self?.isHidden = sender.buttons.isEmpty
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

