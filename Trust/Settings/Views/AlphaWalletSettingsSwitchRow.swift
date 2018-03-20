// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Eureka

public final class AlphaWalletSettingsSwitchRow: _AlphaWalletSettingsSwitchRow, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
    }
}

open class _AlphaWalletSettingsSwitchRow: Row<AlphaWalletSwitchCell> {
    required public init(tag: String?) {
        super.init(tag: tag)
        displayValueFor = nil
    }
}

open class AlphaWalletSwitchCell: Cell<Bool>, CellType {

    let background = UIView()
    @IBOutlet public weak var switchControl: UISwitch!

    required public init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        let switchC = UISwitch()
        switchControl = switchC
        accessoryView = switchControl
        editingAccessoryView = accessoryView

        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(4)
        NSLayoutConstraint.activate([
//            mainLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
//            mainLabel.trailingAnchor.constraint(equalTo: subLabel.leadingAnchor, constant: -10),
//            mainLabel.centerYAnchor.constraint(equalTo: background.centerYAnchor),
//            mainLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 18),
//            mainLabel.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -18),

//            subLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
//            subLabel.centerYAnchor.constraint(equalTo: background.centerYAnchor),
//            subLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 18),
//            subLabel.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -18),

            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -yMargin),
        ])
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func setup() {
        super.setup()
        selectionStyle = .none

        height = { 70 }

        backgroundColor = Colors.appBackground

        contentView.backgroundColor = Colors.appBackground

        background.backgroundColor = Colors.appWhite
        background.layer.cornerRadius = 20

        textLabel?.backgroundColor = Colors.appWhite
        textLabel?.textColor = Colors.appText
        textLabel?.font = Fonts.light(size: 18)!

        switchControl.addTarget(self, action: #selector(AlphaWalletSwitchCell.valueChanged), for: .valueChanged)
    }

    deinit {
        switchControl?.removeTarget(self, action: nil, for: .allEvents)
    }

    open override func update() {
        super.update()
        switchControl.isOn = row.value ?? false
        switchControl.isEnabled = !row.isDisabled
    }

    @objc func valueChanged() {
        row.value = switchControl?.isOn ?? false
    }
}
