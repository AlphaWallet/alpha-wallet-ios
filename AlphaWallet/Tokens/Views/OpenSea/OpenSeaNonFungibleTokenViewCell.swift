// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class OpenSeaNonFungibleTokenView: UIView {
    private let background = UIView()
    private let imageView = WebImageView(type: .thumbnail, size: UICollectionViewFlowLayout.collectiblesItemImageSize)
    //Holder so UIMotionEffect don't reveal the background behind the image
    private let imageHolder = UIView()
    private let label = UILabel()
    private let countLabel = UILabel()

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
            imageHolder.widthAnchor.constraint(equalTo: imageHolder.heightAnchor),
            imageView.anchorsConstraint(to: imageHolder),
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

        if let url = viewModel.imageUrl {
            imageView.url = url
        } else {
            imageView.image = UIImage(named: "AppIcon60x60")
        }

        label.textAlignment = .center
        label.attributedText = viewModel.tickersTitleAttributedString

        countLabel.textAlignment = .center
        countLabel.attributedText = viewModel.tickersAmountAttributedString
    }
}

struct OpenSeaNonFungibleTokenPairTableCellViewModel: Equatable {
    static func == (lhs: OpenSeaNonFungibleTokenPairTableCellViewModel, rhs: OpenSeaNonFungibleTokenPairTableCellViewModel) -> Bool {
        let leftAreEqual = lhs.leftViewModel.tokenAddress.sameContract(as: rhs.leftViewModel.tokenAddress)
        guard let address1 = lhs.rightViewModel?.tokenAddress, let address2 = rhs.rightViewModel?.tokenAddress else {
            return false
        }
        return leftAreEqual && address1.sameContract(as: address2)
    }

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
    private(set) var viewModel: OpenSeaNonFungibleTokenPairTableCellViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)
        selectionStyle = .none

        let stackView = [left, right].asStackView(axis: .horizontal, spacing: spacing)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: background, edgeInsets: edgeInsets),
            background.anchorsConstraint(to: contentView),

            left.widthAnchor.constraint(equalToConstant: cellSize.width),
            right.widthAnchor.constraint(equalToConstant: cellSize.width),
            self.heightAnchor.constraint(equalToConstant: cellSize.height)
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
        self.viewModel = viewModel

        left.configure(viewModel: viewModel.leftViewModel)
        if let viewModel = viewModel.rightViewModel {
            right.configure(viewModel: viewModel)
        }
        right.isHidden = viewModel.rightViewModel == nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        separatorInset = .init(top: 0, left: 1000, bottom: 0, right: 0)
    }
}
