// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Eureka

public final class AlphaWalletSettingsButtonRowOf<T: Equatable> : _AlphaWalletSettingsButtonRowOf<T>, RowType {
	public required init(tag: String?) {
		super.init(tag: tag)
	}
}

public typealias AlphaWalletSettingsButtonRow = AlphaWalletSettingsButtonRowOf<String>

open class _AlphaWalletSettingsButtonRowOf<T: Equatable> : Row<AlphaWalletSettingsButtonCellOf<T>> {
	open var presentationMode: PresentationMode<UIViewController>?

	required public init(tag: String?) {
		super.init(tag: tag)
		displayValueFor = nil
		cellStyle = .default
	}

	open override func customDidSelect() {
		super.customDidSelect()
		if !isDisabled {
			if let presentationMode = presentationMode {
				if let controller = presentationMode.makeController() {
					presentationMode.present(controller, row: self, presentingController: cell.formViewController()!)
				} else {
					presentationMode.present(nil, row: self, presentingController: cell.formViewController()!)
				}
			}
		}
	}

	open override func customUpdateCell() {
		super.customUpdateCell()
		let leftAlignment = presentationMode != nil
		cell.textLabel?.textAlignment = leftAlignment ? .left : .center
		cell.accessoryType = !leftAlignment || isDisabled ? .none : .disclosureIndicator
		cell.editingAccessoryType = cell.accessoryType
	}

	open override func prepare(for segue: UIStoryboardSegue) {
		super.prepare(for: segue)
		(segue.destination as? RowControllerType)?.onDismissCallback = presentationMode?.onDismissCallback
	}
}

open class AlphaWalletSettingsButtonCellOf<T: Equatable>: Cell<T>, CellType {
	let background = UIView()

	required public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)

		background.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(background)

		NSLayoutConstraint.activate([
			background.anchorsConstraint(to: self),
		])
	}

	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	open override func update() {
		super.update()

		height = { 44 }
		backgroundColor = Colors.appBackground

		contentView.backgroundColor = Colors.appBackground

		background.backgroundColor = Colors.appWhite
		background.layer.cornerRadius = Metrics.CornerRadius.box

		textLabel?.backgroundColor = Screen.Setting.Color.background
		textLabel?.textColor = Screen.Setting.Color.title
		textLabel?.font = Screen.Setting.Font.title

		detailTextLabel?.backgroundColor = Screen.Setting.Color.background
		detailTextLabel?.textColor = Screen.Setting.Color.subtitle
		detailTextLabel?.font = Screen.Setting.Font.subtitle

		imageView?.tintColor = Screen.Setting.Color.image

		selectionStyle = .none
		accessoryType = .none
		editingAccessoryType = accessoryType
	}

	open override func didSelect() {
		super.didSelect()
		row.deselect()
	}
}
