// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AssetDefinitionsOverridesViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: AssetDefinitionsOverridesViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        contentView.backgroundColor = viewModel.backgroundColor

        textLabel?.textColor = viewModel.textColor
        textLabel?.font = viewModel.textFont
        textLabel?.lineBreakMode = viewModel.textLineBreakMode
        textLabel?.text = viewModel.text
    }
}
