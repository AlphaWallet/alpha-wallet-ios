//
//  GasSpeedViewModelType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.04.2023.
//

import UIKit

protocol GasSpeedViewModelType {
    var accessoryIcon: UIImage? { get }
    var titleAttributedString: NSAttributedString? { get }
    var detailsAttributedString: NSAttributedString? { get }
    var gasPriceAttributedString: NSAttributedString? { get }
    var estimatedTimeAttributedString: NSAttributedString? { get }
}
