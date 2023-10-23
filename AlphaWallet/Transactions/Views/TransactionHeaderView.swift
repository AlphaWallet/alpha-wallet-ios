// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import AlphaWalletCore
import AlphaWalletFoundation
import Combine

struct TransactionHeaderViewModel {
    private let transactionViewModel: TransactionViewModel
    private let tokensService: TokensProcessingPipeline
    private let tokenImageFetcher: TokenImageFetcher

    var server: RPCServer { transactionViewModel.server }
    var amount: NSAttributedString {
        NSAttributedString(string: transactionViewModel.fullAmountAttributedString.string, attributes: [
            .font: Fonts.semibold(size: 20) as Any,
            .foregroundColor: Configuration.Color.Semantic.defaultHeadlineText,
        ])
    }

    init(transactionViewModel: TransactionViewModel,
         tokensService: TokensProcessingPipeline,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.transactionViewModel = transactionViewModel
        self.tokensService = tokensService
    }

    private var operation: LocalizedOperation? {
        switch transactionViewModel.transactionRow {
        case .standalone(let transaction): return transaction.operation
        case .group: return nil
        case .item(_, let op): return op
        }
    }

    private var operationTitle: String? {
        if let operation = operation {
            switch operation.operationType {
            case .nativeCurrencyTokenTransfer, .erc20TokenTransfer, .erc721TokenTransfer, .erc875TokenTransfer, .erc1155TokenTransfer:
                return R.string.localizable.transactionCellTokenTransferTitle(operation.symbol ?? "")
            case .erc20TokenApprove:
                return R.string.localizable.transactionCellTokenApproveTitle(operation.symbol ?? "")
            case .erc721TokenApproveAll:
                return R.string.localizable.transactionCellTokenApproveAllTitle(operation.symbol ?? "")
            case .unknown:
                return nil
            }
        } else {
            return nil
        }
    }

    var titleTextColor: UIColor {
        return Configuration.Color.Semantic.defaultForegroundText
    }

    var title: String {
        if let operationTitle = operationTitle {
            return operationTitle
        }

        switch transactionViewModel.transactionRow.state {
        case .completed:
            switch transactionViewModel.direction {
            case .incoming: return R.string.localizable.transactionCellReceivedTitle()
            case .outgoing: return R.string.localizable.transactionCellSentTitle()
            }
        case .error: return R.string.localizable.transactionCellErrorTitle()
        case .failed: return R.string.localizable.transactionCellFailedTitle()
        case .unknown: return R.string.localizable.transactionCellUnknownTitle()
        case .pending: return R.string.localizable.transactionCellPendingTitle()
        }
    }

    var subTitle: String {
        switch transactionViewModel.direction {
        case .incoming: return "\(transactionViewModel.transactionRow.from)"
        case .outgoing: return "\(transactionViewModel.transactionRow.to)"
        }
    }

    var tokenImageSource: TokenImagePublisher {
        let server = transactionViewModel.transactionRow.server

        guard let operation = operation, let contractAddress = operation.contractAddress else {
            let token = MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
            return tokenImageFetcher.image(token: token, size: .s300)
        }

        return asFuture {
            await tokensService.tokenViewModel(for: contractAddress, server: server)
        }.flatMap {
            if let tokenViewModel = $0 {
                return tokenImageFetcher.image(token: tokenViewModel, size: .s300)
            } else {
                return .just(nil)
            }
        }.eraseToAnyPublisher()
    }
}

class TransactionHeaderView: UIView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = Fonts.semibold(size: 17)
        label.textColor = Configuration.Color.Semantic.defaultHeadlineText
        label.numberOfLines = 0

        return label
    }()

    private let toLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.isHidden = true

        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.isHidden = true

        return label
    }()

    private var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        imageView.rounding = .circle
        imageView.isChainOverlayHidden = true
        imageView.contentMode = .scaleAspectFit

        return imageView
    }()

    private let line: UIView = .separator()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            dateLabel,
            .spacer(height: 10),
            tokenIconImageView,
            .spacer(height: 10),
            titleLabel,
            .spacer(height: 10),
            toLabel
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        addSubview(line)

        let margin = CGFloat(15)
        NSLayoutConstraint.activate([
            tokenIconImageView.sized(.init(width: 64, height: 64)),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: margin),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -margin),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),

            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TransactionHeaderViewModel) {
        titleLabel.text = viewModel.title
        titleLabel.textColor = viewModel.titleTextColor
        toLabel.text = viewModel.subTitle
        tokenIconImageView.set(imageSource: viewModel.tokenImageSource)
    }
}
