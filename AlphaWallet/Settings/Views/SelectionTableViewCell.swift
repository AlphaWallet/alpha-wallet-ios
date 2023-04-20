// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import Combine

class SelectionTableViewCell: UITableViewCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    private var cancellable = Set<AnyCancellable>()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let stackView = [
            iconImageView, titleLabel, .spacerWidth(flexible: true)
        ].asStackView(axis: .horizontal, spacing: 16, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 10, left: 16, bottom: 10, right: 20))
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SelectionTableViewCellModel) {
        cancellable.cancellAll()

        titleLabel.text = viewModel.titleText
        titleLabel.font = viewModel.titleFont
        titleLabel.textColor = viewModel.titleTextColor
        iconImageView.image = viewModel.icon
        selectionStyle = .default

        viewModel.accessoryType
            .assign(to: \.accessoryType, on: self)
            .store(in: &cancellable)
    }
}

struct SelectionTableViewCellModel {
    let titleText: String
    let icon: UIImage
    let value: AnyPublisher<Bool, Never>

    var titleFont: UIFont = Fonts.regular(size: 17)
    var titleTextColor: UIColor = Configuration.Color.Semantic.tableViewCellPrimaryFont

    var accessoryType: AnyPublisher<UITableViewCell.AccessoryType, Never> {
        value.map { $0 ? UITableViewCell.AccessoryType.checkmark : UITableViewCell.AccessoryType.none }
            .eraseToAnyPublisher()
    }
}

extension SelectionTableViewCellModel: Hashable {
   static func == (lhs: SelectionTableViewCellModel, rhs: SelectionTableViewCellModel) -> Bool {
        return lhs.titleText == rhs.titleText && lhs.icon == rhs.icon && lhs.value == rhs.value
    }
}
