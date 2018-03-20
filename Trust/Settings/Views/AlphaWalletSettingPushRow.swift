// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Eureka

/// A selector row where the user can pick an option from a pushed view controller
public final class AlphaWalletSettingPushRow<T: Equatable> : _PushRow<AlphaWalletSettingsPushSelectorCell<T>>, RowType {
    public required init(tag: String?) {
        super.init(tag: tag)
    }
}

open class AlphaWalletSettingsPushSelectorCell<T: Equatable> : Cell<T>, CellType {
    let background = UIView()

    required public init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
		
        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(4)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -yMargin),
        ])
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func update() {
        super.update()

        height = { 70 }
        backgroundColor = Colors.appBackground
        accessoryType = .disclosureIndicator
        editingAccessoryType = accessoryType
        selectionStyle = .none

        contentView.backgroundColor = Colors.appBackground

        background.backgroundColor = Colors.appWhite
        background.layer.cornerRadius = 20

        textLabel?.textColor = Colors.appText
        textLabel?.font = Fonts.light(size: 18)!

        detailTextLabel?.textColor = Colors.appText
        detailTextLabel?.font = Fonts.light(size: 18)!
    }
}
