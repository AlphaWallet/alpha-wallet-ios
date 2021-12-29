// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class OpenSeaNonFungibleTokenView: UIView {
    private let background = UIView()
    private let imageView = TokenImageView()
    //Holder so UIMotionEffect don't reveal the background behind the image
    private let imageHolder = UIView()
    private let label = UILabel()
    private let countLabel = UILabel()
    private var tokenAddress: AlphaWallet.Address?

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

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageHolder.addSubview(imageView)

        NSLayoutConstraint.activate([
            background.anchorsConstraint(to: self, edgeInsets: .zero),

            stackView.anchorsConstraint(to: background),
            imageView.anchorsConstraint(to: imageHolder),
            textsStackView.heightAnchor.constraint(equalToConstant: 40)
        ])
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        DispatchQueue.main.async {
            self.setupParallaxEffect(forView: self.imageView, max: 20)
        }
    }

    func configure(viewModel: OpenSeaNonFungibleTokenViewCellViewModel) {
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = viewModel.contentsCornerRadius
        background.clipsToBounds = true
        background.borderWidth = 1
        background.borderColor = R.color.mercury()

        imageHolder.clipsToBounds = true

        if let tokenAddress = tokenAddress {
            if tokenAddress.sameContract(as: viewModel.tokenAddress) {
                //no-op
            } else {
                imageView.subscribable = viewModel.tokenIcon
            }
        } else {
            imageView.subscribable = viewModel.tokenIcon
        }

        imageView.subscribable = viewModel.tokenIcon

        label.textAlignment = .center
        label.attributedText = viewModel.tickersTitleAttributedString

        countLabel.textAlignment = .center
        countLabel.attributedText = viewModel.tickersAmountAttributedString

        tokenAddress = viewModel.tokenAddress
    }
}

struct OpenSeaNonFungibleTokenPairTableCellViewModel {
    var leftViewModel: OpenSeaNonFungibleTokenViewCellViewModel
    var rightViewModel: OpenSeaNonFungibleTokenViewCellViewModel?
}

protocol OpenSeaNonFungibleTokenPairTableCellDelegate: class {
    func didSelect(cell: OpenSeaNonFungibleTokenPairTableCell, indexPath: IndexPath, isLeftCardSelected: Bool)
}

class OpenSeaNonFungibleTokenPairTableCell: UITableViewCell {
    private lazy var left: OpenSeaNonFungibleTokenView = {
        return OpenSeaNonFungibleTokenView.init(frame: .zero)
    }()

    private lazy var right: OpenSeaNonFungibleTokenView = {
        return OpenSeaNonFungibleTokenView.init(frame: .zero)
    }()
    private let background = UIView()

    private var spacing: CGFloat {
        return 16
    }

    var edgeInsets: UIEdgeInsets {
        return .init(top: 16, left: 16, bottom: 0, right: 16)
    }

    private var cellWidth: CGFloat {
        let width = UIScreen.main.bounds.size.width - edgeInsets.left - edgeInsets.right - spacing
        return width / 2
    }

    var cellSize: CGSize {
        let width = UIScreen.main.bounds.size.width - edgeInsets.left - edgeInsets.right - spacing
        return .init(width: width / 2, height: UICollectionViewFlowLayout.collectiblesItemSize.height - edgeInsets.bottom - edgeInsets.top)
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

            right.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 16)
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
}
