// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

// Override showCheckbox() to return true or false
class BaseTokenCardTableViewCell: UITableViewCell {
    static let identifier = "TokenCardTableViewCell"
    //This is declared optional because we have no way to set it upon cell instance creation. But it has to be set immediately. Check where it's accessed. It's forced unwrapped
    private var assetDefinitionStore: AssetDefinitionStore? = nil

    //TODO Remove server? But do we actually need to inject the chain ID into the webview for this?
    //TODO it's ok to hardcode to.viewIconified for now, we are setting it to the correct value in configure()
    private lazy var rowView = TokenCardRowView(server: .main, tokenView: .viewIconified, showCheckbox: showCheckbox(), assetDefinitionStore: assetDefinitionStore!)

    var isWebViewInteractionEnabled: Bool = false {
        didSet {
            rowView.isWebViewInteractionEnabled = isWebViewInteractionEnabled
        }
    }

    func configure(viewModel: BaseTokenCardTableViewCellViewModel, assetDefinitionStore: AssetDefinitionStore) {
        setUpRowView(withAssetDefinitionStore: assetDefinitionStore)

        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        contentView.backgroundColor = viewModel.backgroundColor

        rowView.tokenView = viewModel.tokenView
        rowView.configure(viewModel: TokenCardRowViewModel(tokenHolder: viewModel.tokenHolder, tokenView: viewModel.tokenView, assetDefinitionStore: assetDefinitionStore))

        if showCheckbox() {
            rowView.checkboxImageView.image = viewModel.checkboxImage
        }

        rowView.stateLabel.text = "      \(viewModel.status)      "
        rowView.stateLabel.isHidden = viewModel.status.isEmpty

        rowView.areDetailsVisible = viewModel.areDetailsVisible
    }

    func showCheckbox() -> Bool {
        return true
    }

    func reflectCheckboxVisibility() {
        rowView.showCheckbox = showCheckbox()
    }

    //Body of this function was moved from init(style:reuseIdentifier:) because AssetDefinitionStore is defined as optional because we have no way to initialize it when a cell is created, yet it should work as a non-optional
    private func setUpRowView(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
        guard rowView.superview == nil else { return }

        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}
