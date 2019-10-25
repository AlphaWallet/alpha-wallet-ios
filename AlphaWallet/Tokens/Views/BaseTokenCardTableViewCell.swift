// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol BaseTokenCardTableViewCellDelegate: class {
    func didTapURL(url: URL)
}

// Override showCheckbox() to return true or false
class BaseTokenCardTableViewCell: UITableViewCell {
    static let identifier = "TokenCardTableViewCell"
    //This is declared optional because we have no way to set it upon cell instance creation. But it has to be set immediately. Check where it's accessed. It's forced unwrapped
    private var assetDefinitionStore: AssetDefinitionStore? = nil

    weak var delegate: BaseTokenCardTableViewCellDelegate?

    var rowView: (TokenCardRowViewProtocol & UIView)? {
        didSet {
            //Important to check that rowView has changed, so that we only remove the previous version. There's perhaps a system bug that calls this didSet-observer even when we are just reading the property. Hence the check is important to avoid removing the current rowView
            guard rowView !== oldValue else { return }
            oldValue?.removeFromSuperview()
        }
    }

    func configure(viewModel: BaseTokenCardTableViewCellViewModel, assetDefinitionStore: AssetDefinitionStore) {
        setUpRowView(withAssetDefinitionStore: assetDefinitionStore)

        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        contentView.backgroundColor = viewModel.backgroundColor

        rowView?.tokenView = viewModel.tokenView
        rowView?.configure(tokenHolder: viewModel.tokenHolder, tokenView: viewModel.tokenView, areDetailsVisible: viewModel.areDetailsVisible, width: viewModel.cellWidth, assetDefinitionStore: assetDefinitionStore)

        if showCheckbox() {
            rowView?.checkboxImageView.image = viewModel.checkboxImage
        }

        rowView?.stateLabel.text = "      \(viewModel.status)      "
        rowView?.stateLabel.isHidden = viewModel.status.isEmpty

        rowView?.areDetailsVisible = viewModel.areDetailsVisible
    }

    func showCheckbox() -> Bool {
        return true
    }

    func reflectCheckboxVisibility() {
        rowView?.showCheckbox = showCheckbox()
    }

    //Body of this function was moved from init(style:reuseIdentifier:) because AssetDefinitionStore is defined as optional because we have no way to initialize it when a cell is created, yet it should work as a non-optional
    private func setUpRowView(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
        guard let rowView = rowView else { return }
        guard rowView.superview == nil else { return }

        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        NSLayoutConstraint.activate([
            rowView.anchorsConstraint(to: contentView),
        ])
    }
}

extension BaseTokenCardTableViewCell: OpenSeaNonFungibleTokenCardRowViewDelegate {
    func didTapURL(url: URL) {
        delegate?.didTapURL(url: url)
    }
}
