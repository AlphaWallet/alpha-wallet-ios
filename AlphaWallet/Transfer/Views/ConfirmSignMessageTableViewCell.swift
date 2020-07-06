// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class ConfirmSignMessageTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ConfirmSignMessageTableViewCellViewModel) {
        contentView.backgroundColor = viewModel.backgroundColor
        selectionStyle = .none

        textLabel?.font = viewModel.nameTextFont

        detailTextLabel?.numberOfLines = 0
        detailTextLabel?.font = viewModel.valueTextFont
        detailTextLabel?.textColor = viewModel.valueTextColor

        textLabel?.text = viewModel.name
        detailTextLabel?.text = viewModel.value
    }
}
