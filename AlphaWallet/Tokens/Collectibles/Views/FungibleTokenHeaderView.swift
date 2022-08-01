// Copyright © 2018 Stormbird PTE. LTD.
import UIKit
import Combine

protocol FungibleTokenHeaderViewDelegate: AnyObject {
    func didPressViewContractWebPage(inHeaderView: FungibleTokenHeaderView)
}

class FungibleTokenHeaderView: UIView {
    weak var delegate: FungibleTokenHeaderViewDelegate?

    private var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        return label
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        return label
    }()
    private let toggleValue = PassthroughSubject<Void, Never>()
    private var blockChainTagLabel = BlockchainTagLabel()
    private var cancelable = Set<AnyCancellable>()

    let viewModel: FungibleTokenHeaderViewModel

    init(viewModel: FungibleTokenHeaderViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        let stackView = [
            tokenIconImageView,
            titleLabel,
            valueLabel,
            blockChainTagLabel
        ].asStackView(axis: .vertical, spacing: 5, alignment: .center)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            tokenIconImageView.heightAnchor.constraint(equalToConstant: DataEntry.Metric.SendHeader.iconSide),
            tokenIconImageView.widthAnchor.constraint(equalToConstant: DataEntry.Metric.SendHeader.iconSide),
            stackView.anchorsConstraint(to: self, edgeInsets: DataEntry.Metric.SendHeader.insets)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(showContractWebPage))
        tokenIconImageView.addGestureRecognizer(tap)

        let tap1 = UITapGestureRecognizer(target: self, action: #selector(showHideMarketSelected))
        valueLabel.addGestureRecognizer(tap1)

        bind(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func bind(viewModel: FungibleTokenHeaderViewModel) {
        backgroundColor = viewModel.backgroundColor

        tokenIconImageView.subscribable = viewModel.iconImage
        blockChainTagLabel.configure(viewModel: viewModel.blockChainTagViewModel)

        let input = FungibleTokenHeaderViewModelInput(toggleValue: toggleValue.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)
        output.viewState.sink { [weak titleLabel, weak valueLabel] state in
            titleLabel?.attributedText = state.title
            valueLabel?.attributedText = state.value
        }.store(in: &cancelable)
    }

    @objc private func showContractWebPage() {
        delegate?.didPressViewContractWebPage(inHeaderView: self)
    }

    @objc private func showHideMarketSelected(_ sender: UITapGestureRecognizer) {
        guard !viewModel.server.isTestnet else { return }

        toggleValue.send(())
    }
}
