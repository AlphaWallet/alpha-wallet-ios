// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol BaseCryptoKittyTokenCardTableViewCellDelegate: class {
    func didTapURL(url: URL)
}

//TODO might be unnecessary in the future. Full-text search for TokenRowViewProtocol
// Override showCheckbox() to return true or false
class BaseCryptoKittyTokenCardTableViewCell: UITableViewCell {
    static let identifier = "BaseCryptoKittyTokenCardTableViewCell"

    private lazy var rowView: CryptoKittyCardRowView = {
        let result = CryptoKittyCardRowView(showCheckbox: showCheckbox())
        result.delegate = self
        return result
    }()
    weak var delegate: BaseCryptoKittyTokenCardTableViewCellDelegate?

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        rowView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowView)

        NSLayoutConstraint.activate([
            rowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            rowView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: BaseTokenCardTableViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        contentView.backgroundColor = viewModel.backgroundColor

        rowView.configure(viewModel: .init(tokenHolder: viewModel.tokenHolder, areDetailsVisible: viewModel.areDetailsVisible))

        if showCheckbox() {
            rowView.checkboxImageView.image = viewModel.checkboxImage
        }

        rowView.stateLabel.text = "      \(viewModel.status)      "
        rowView.stateLabel.isHidden = viewModel.status.isEmpty
        rowView.stateLabel.backgroundColor = viewModel.stateBackgroundColor
    }

    func showCheckbox() -> Bool {
        return true
    }
}

extension BaseCryptoKittyTokenCardTableViewCell: CryptoKittyCardRowViewDelegate {
    func didTapURL(url: URL) {
        delegate?.didTapURL(url: url)
    }
}
