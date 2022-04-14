// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
class AccountViewCell: UITableViewCell {
    private let addressLabel = UILabel()
    private let apprecation24hourLabel = UILabel()
    private let balanceLabel = UILabel()
    private let blockieImageView = BlockieImageView(size: .init(width: 40, height: 40))
    lazy private var selectedIndicator: UIView = {
        let indicator = UIView()
        indicator.layer.cornerRadius = Style.SelectionIndicator.width/2.0
        indicator.borderWidth = 0.0
        indicator.backgroundColor = Style.SelectionIndicator.color
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: Style.SelectionIndicator.width),
            indicator.heightAnchor.constraint(equalToConstant: Style.SelectionIndicator.height)
        ])
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isHidden = true
        return indicator
    }()
    var viewModel: AccountViewModel?
    var account: Wallet?

    private var cancelable = Set<AnyCancellable>()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        separatorInset = .zero
        selectionStyle = .none
        isUserInteractionEnabled = true
        addressLabel.lineBreakMode = .byTruncatingMiddle

        let leftStackView = [
            [balanceLabel, apprecation24hourLabel].asStackView(spacing: 10),
            addressLabel
        ].asStackView(axis: .vertical)

        let stackView = [blockieImageView, leftStackView, .spacerWidth(10)].asStackView(spacing: 12, alignment: .top)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)
        contentView.addSubview(selectedIndicator)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            stackView.rightAnchor.constraint(equalTo: rightAnchor, constant: -25),
            selectedIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            selectedIndicator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Style.SelectionIndicator.leadingOffset)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: AccountViewModel) {
        self.viewModel = viewModel
        cancelable.cancellAll()
        backgroundColor = viewModel.backgroundColor

        addressLabel.attributedText = viewModel.addressesAttrinutedString

        accessoryView = Style.AccessoryView.chevron

        selectedIndicator.isHidden = !viewModel.isSelected

        viewModel
            .blockiesImage
            .receive(on: RunLoop.main)
            .sink { [weak blockieImageView] image in
                blockieImageView?.setBlockieImage(image: image)
            }.store(in: &cancelable)

        viewModel.balance
            .receive(on: RunLoop.main)
            .sink { [weak balanceLabel] value in
                balanceLabel?.attributedText = value
            }.store(in: &cancelable)

        viewModel.apprecation24hour
            .receive(on: RunLoop.main)
            .sink { [weak apprecation24hourLabel] value in
                apprecation24hourLabel?.attributedText = value
            }.store(in: &cancelable)
    }
}
