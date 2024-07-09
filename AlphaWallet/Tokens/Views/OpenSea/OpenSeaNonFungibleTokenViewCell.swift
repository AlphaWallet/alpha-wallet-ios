// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class OpenSeaNonFungibleTokenView: UIView {
    private let background = UIView()
    let tokenImageView: TokenImageView = {
        let imageView: TokenImageView = TokenImageView()
        imageView.rounding = .none
        imageView.isChainOverlayHidden = true
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isSymbolLabelHidden = true
        imageView.loading = .disabled

        return imageView
    }()
    private let imageHolder = UIView()
    private let label: UILabel = {
        let label = UILabel()
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        return label
    }()
    private let countLabel: UILabel = {
        let countLabel = UILabel()
        countLabel.setContentHuggingPriority(.required, for: .vertical)
        countLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        return countLabel
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)

        let textsStackView = [
            label,
            countLabel,
        ].asStackView(axis: .vertical)

        let stackView = [
            imageHolder,
            .spacer(height: 8),
            [.spacerWidth(8), textsStackView, .spacerWidth(8)].asStackView(axis: .horizontal),
            .spacer(height: 8),
        ].asStackView(axis: .vertical, spacing: 0, alignment: .fill)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        background.addSubview(stackView)
        imageHolder.addSubview(tokenImageView)

        NSLayoutConstraint.activate([
            background.anchorsConstraint(to: self, edgeInsets: .zero),

            stackView.anchorsConstraint(to: background),
            tokenImageView.anchorsConstraint(to: imageHolder),
        ])

        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: OpenSeaNonFungibleTokenViewCellViewModel) {
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = viewModel.contentsCornerRadius
        background.clipsToBounds = true
        background.borderWidth = 1
        background.borderColor = Configuration.Color.Semantic.tableViewSeparator

        imageHolder.clipsToBounds = true
        tokenImageView.set(imageSource: viewModel.tokenIcon)

        label.textAlignment = .center
        label.attributedText = viewModel.titleAttributedString

        countLabel.textAlignment = .center
        countLabel.attributedText = viewModel.assetsCountAttributedString
    }
}

struct OpenSeaNonFungibleTokenPairTableCellViewModel {
    var leftViewModel: OpenSeaNonFungibleTokenViewCellViewModel
    var rightViewModel: OpenSeaNonFungibleTokenViewCellViewModel?
}

extension OpenSeaNonFungibleTokenPairTableCellViewModel: Hashable {
    static func == (lhs: OpenSeaNonFungibleTokenPairTableCellViewModel, rhs: OpenSeaNonFungibleTokenPairTableCellViewModel) -> Bool {
        return lhs.leftViewModel == rhs.leftViewModel && lhs.rightViewModel == rhs.rightViewModel
    }
}

protocol OpenSeaNonFungibleTokenPairTableCellDelegate: AnyObject {
    func didSelect(cell: OpenSeaNonFungibleTokenPairTableCell, indexPath: IndexPath, isLeftCardSelected: Bool)
}

class OpenSeaNonFungibleTokenPairTableCell: UITableViewCell {
    private lazy var left: OpenSeaNonFungibleTokenView = {
        return OpenSeaNonFungibleTokenView(frame: .zero)
    }()

    private lazy var right: OpenSeaNonFungibleTokenView = {
        return OpenSeaNonFungibleTokenView(frame: .zero)
    }()
    private let background = UIView()

    private var spacing: CGFloat {
        return 16
    }

    private var edgeInsets: UIEdgeInsets {
        return .init(top: 16, left: 16, bottom: 0, right: 16)
    }

    private var cellSize: CGSize {
        let width = UIScreen.main.bounds.size.width - edgeInsets.left - edgeInsets.right - spacing
        return .init(width: width / 2, height: 0)
    }
    weak var delegate: OpenSeaNonFungibleTokenPairTableCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none

        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)
        background.addSubview(left)
        background.addSubview(right)

        NSLayoutConstraint.activate([
            background.anchorsConstraint(to: contentView),
            left.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            left.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            left.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            left.widthAnchor.constraint(equalToConstant: cellSize.width),

            right.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
            right.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            right.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            right.widthAnchor.constraint(equalToConstant: cellSize.width),

            right.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 16),
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellSelected))
        isUserInteractionEnabled = true
        addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func cellSelected(_ sender: UITapGestureRecognizer) {
        guard let indexPath = self.indexPath else { return }

        if left.bounds.contains(sender.location(in: self)) {
            delegate?.didSelect(cell: self, indexPath: indexPath, isLeftCardSelected: true)
        } else {
            guard !right.isHidden else { return }
            delegate?.didSelect(cell: self, indexPath: indexPath, isLeftCardSelected: false)
        }
    }

    func configure(viewModel: OpenSeaNonFungibleTokenPairTableCellViewModel) {
        left.configure(viewModel: viewModel.leftViewModel)
        if let viewModel = viewModel.rightViewModel {
            right.configure(viewModel: viewModel)
        }
        right.isHidden = viewModel.rightViewModel == nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        left.tokenImageView.cancel()
        right.tokenImageView.cancel()
    }
}
