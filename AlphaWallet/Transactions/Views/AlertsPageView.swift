//
//  AlertsPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit

class AlertsPageView: UIView, TokenPageViewType {
    let title: String = "Alerts"

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .green
    }

    required init?(coder: NSCoder) {
        return nil
    }
}
