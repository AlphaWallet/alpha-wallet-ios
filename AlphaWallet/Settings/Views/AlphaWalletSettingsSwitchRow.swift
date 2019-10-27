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
    private let background = UIView()

    @IBOutlet public weak var switchControl: UISwitch!

    required public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        let switchC = UISwitch()
        switchControl = switchC
        accessoryView = switchControl
        editingAccessoryView = accessoryView

        NSLayoutConstraint.activate([
            background.anchorsConstraint(to: self),
        ])
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func setup() {
        super.setup()
        selectionStyle = .none

        height = { 44 }

        backgroundColor = Colors.appBackground

        contentView.backgroundColor = Colors.appBackground

        background.backgroundColor = Colors.appWhite
        background.layer.cornerRadius = Metrics.CornerRadius.box

        textLabel?.backgroundColor = Screen.Setting.Color.background
        textLabel?.textColor = Screen.Setting.Color.title
        textLabel?.font = Screen.Setting.Font.title

        imageView?.tintColor = Screen.Setting.Color.image

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
