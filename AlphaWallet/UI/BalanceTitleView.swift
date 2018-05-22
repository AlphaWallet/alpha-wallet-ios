// Copyright SIX DAY LLC. All rights reserved.

import UIKit

enum BalanceMode {
    case short
    case full
}

class BalanceTitleView: UIView {

    @objc dynamic var titleTextColor: UIColor? {
        get { return self.titleLabel.textColor }
        set { self.titleLabel.textColor = newValue }
    }

    @objc dynamic var subTitleTextColor: UIColor? {
        get { return self.subTitleLabel.textColor }
        set { self.subTitleLabel.textColor = newValue }
    }

    let titleLabel = UILabel()
    let subTitleLabel = UILabel()
    var viewModel: BalanceBaseViewModel? {
        didSet {
            guard let viewModel = viewModel else { return }
            configure(viewModel: viewModel)
        }
    }
    private var mode = BalanceMode.short

    override init(frame: CGRect) {
        super.init(frame: .zero)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true

        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.textAlignment = .center
        subTitleLabel.adjustsFontSizeToFitWidth = true

        let stackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical, spacing: 2)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        stackView.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(self.switchModel))
        )
    }

    private func configure(viewModel: BalanceBaseViewModel) {
        titleLabel.font = Fonts.semibold(size: 18)
        subTitleLabel.font = Fonts.regular(size: 14)

        let amount: String
        switch mode {
        case .full:
            amount = viewModel.amountFull
        case .short:
            amount = viewModel.amountShort
        }

        titleLabel.text = "\(amount) \(viewModel.symbol)"
        subTitleLabel.text = viewModel.currencyAmount
    }

    @objc func switchModel() {
        switch mode {
        case .full:
            mode = .short
        case .short:
            mode = .full
        }

        guard let viewModel = viewModel else { return }
        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension BalanceTitleView {
    static func make(from session: WalletSession, _ transferType: TransferType) -> BalanceTitleView {
        let view = BalanceTitleView(frame: .zero)
        view.translatesAutoresizingMaskIntoConstraints = false
        switch transferType {
        case .ether:
            session.balanceViewModel.subscribe { [weak view] viewModel in
                guard let viewModel = viewModel else { return }
                view?.viewModel = viewModel
            }
        case .token(let token):
            view.viewModel = BalanceTokenViewModel(token: token)
        case .stormBird(let token):
            view.viewModel = BalanceTokenViewModel(token: token)
        case .stormBirdOrder: break
        }
        session.refresh(.ethBalance)
        return view
    }
}
