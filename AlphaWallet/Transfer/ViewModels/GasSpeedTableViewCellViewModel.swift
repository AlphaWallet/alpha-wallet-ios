//
//  GasSpeedTableViewCellViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit

struct GasSpeedTableViewCellViewModel {
    var speed: String?
    var estimatedTime: String?
    var details: String?
    let isSelected: Bool

    var accessoryType: UITableViewCell.AccessoryType {
        return isSelected ? .checkmark : .none
    }

    var speedAttributedString: NSAttributedString? {
        guard let speed = speed else { return nil }

        return NSAttributedString(string: speed, attributes: [
            .foregroundColor: Colors.black,
            .font: Fonts.regular(size: 17)!
        ])
    }

    var estimatedTimeAttributedString: NSAttributedString? {
        guard let estimatedTime = estimatedTime else { return nil }

        return NSAttributedString(string: estimatedTime, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 13)!
        ])
    }

    var detailsAttributedString: NSAttributedString? {
        guard let details = details else { return nil }

        return NSAttributedString(string: details, attributes: [
            .foregroundColor: R.color.dove()!,
            .font: Fonts.regular(size: 13)!
        ])
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
}

