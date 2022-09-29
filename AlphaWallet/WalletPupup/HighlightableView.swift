//
//  HighlightableView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit

extension UIControl.State: Hashable { }

class HighlightableView: UIView {
    private var colors: [UIControl.State: UIColor] = [:]

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func set(backgroundColor: UIColor?, forState state: UIControl.State) {
        colors[state] = backgroundColor
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        backgroundColor = colors[.highlighted]
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        backgroundColor = colors[.normal]
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        backgroundColor = colors[.normal]
    }
}
