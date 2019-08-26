// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Alamofire

protocol TokenListFormatRowViewDelegate: class {
    func didTapURL(url: URL)
}

//TODO probably remove this class
class TokenListFormatRowView: UIView {
    let checkboxImageView = UIImageView(image: R.image.ticket_bundle_unchecked())
    weak var delegate: TokenListFormatRowViewDelegate?
    let background = UIView()
    let stateLabel = UILabel()
    let tokenView: TokenView = .viewIconified
    //TODO We don't display this for now. Maybe should have flag to show/hide it
    let tokenCountLabel = UILabel()
    private let thumbnailImageView = UIImageView()
    //TODO this imageView is not used yet
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private var detailLabels = [UILabel]()
    private let detailsRowStack: UIStackView
    private let detailsRowWrapperStack: UIStackView
    private let urlButton = UIButton(type: .system)
    private let showCheckbox: Bool
    private var viewModel: TokenListFormatRowViewModel?
    var areDetailsVisible = false {
        didSet {
            if areDetailsVisible {
                descriptionLabel.numberOfLines = 0
                detailsRowWrapperStack.isHidden = false
                urlButton.isHidden = false
            } else {
                descriptionLabel.numberOfLines = 1
                detailsRowWrapperStack.isHidden = true
                urlButton.isHidden = true
            }
        }
    }

    init(showCheckbox: Bool = false) {
        self.showCheckbox = showCheckbox

        checkboxImageView.translatesAutoresizingMaskIntoConstraints = false

        background.translatesAutoresizingMaskIntoConstraints = false

        let topRowStack = [titleLabel].asStackView(spacing: 15, contentHuggingPriority: .required)
        detailsRowStack = [].asStackView(axis: .vertical, contentHuggingPriority: .required)

        detailsRowWrapperStack = [
            .spacer(height: 10),
            detailsRowStack,
        ].asStackView(axis: .vertical, contentHuggingPriority: .required)
        detailsRowWrapperStack.isHidden = true
        urlButton.isHidden = true
        
        super.init(frame: .zero)

        if showCheckbox {
            addSubview(checkboxImageView)
        }

        addSubview(background)

        urlButton.addTarget(self, action: #selector(tappedUrl), for: .touchUpInside)

        let col0 = [
            stateLabel,
            topRowStack,
            subtitleLabel,
            descriptionLabel,
        ].asStackView(axis: .vertical, contentHuggingPriority: .required)
        col0.translatesAutoresizingMaskIntoConstraints = false
        col0.alignment = .leading

        let topStack = [
            col0,
            thumbnailImageView,
        ].asStackView(axis: .horizontal, contentHuggingPriority: .required)
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.alignment = .leading

        let stackView = [
            topStack,
            .spacer(height: 10),
            detailsRowWrapperStack,
            urlButton,
        ].asStackView(axis: .vertical, contentHuggingPriority: .required)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .leading
        background.addSubview(stackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(5)
        var checkboxRelatedConstraints = [NSLayoutConstraint]()
        if showCheckbox {
            checkboxRelatedConstraints.append(checkboxImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
            checkboxRelatedConstraints.append(checkboxImageView.centerYAnchor.constraint(equalTo: centerYAnchor))
            checkboxRelatedConstraints.append(background.leadingAnchor.constraint(equalTo: checkboxImageView.trailingAnchor, constant: xMargin))
            if ScreenChecker().isNarrowScreen {
                checkboxRelatedConstraints.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 20))
                checkboxRelatedConstraints.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 20))
            } else {
                //Have to be hardcoded and not rely on the image's size because different string lengths for the text fields can force the checkbox to shrink
                checkboxRelatedConstraints.append(checkboxImageView.widthAnchor.constraint(equalToConstant: 28))
                checkboxRelatedConstraints.append(checkboxImageView.heightAnchor.constraint(equalToConstant: 28))
            }
        } else {
            checkboxRelatedConstraints.append(background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin))
        }

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),

            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -yMargin),

            thumbnailImageView.widthAnchor.constraint(equalToConstant: 44),
            thumbnailImageView.widthAnchor.constraint(equalTo: thumbnailImageView.heightAnchor),

            stateLabel.heightAnchor.constraint(equalToConstant: 22),
        ] + checkboxRelatedConstraints)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tappedUrl() {
        guard let url = viewModel?.externalLink else { return }
        delegate?.didTapURL(url: url)
    }

    func configure(viewModel: TokenListFormatRowViewModel) {
        self.viewModel = viewModel

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = Metrics.CornerRadius.box
        background.layer.shadowRadius = 3
        background.layer.shadowColor = UIColor.black.cgColor
        background.layer.shadowOffset = CGSize(width: 0, height: 0)
        background.layer.shadowOpacity = 0.14
        background.layer.borderColor = UIColor.black.cgColor

        stateLabel.backgroundColor = viewModel.stateBackgroundColor
        stateLabel.layer.cornerRadius = 8
        stateLabel.clipsToBounds = true
        stateLabel.textColor = viewModel.stateColor
        stateLabel.font = viewModel.subtitleFont

        tokenCountLabel.textColor = viewModel.countColor
        tokenCountLabel.font = viewModel.tokenCountFont

        descriptionLabel.textColor = viewModel.titleColor
        descriptionLabel.font = viewModel.descriptionFont

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont

        subtitleLabel.textColor = viewModel.titleColor
        subtitleLabel.font = viewModel.titleFont

        urlButton.titleLabel?.font = viewModel.urlButtonFont
        urlButton.setTitleColor(viewModel.urlButtonColor, for: .normal)
        urlButton.setTitle(viewModel.urlButtonText, for: .normal)

        displayDetails(viewModel: viewModel)

        tokenCountLabel.text = viewModel.tokenCount

        descriptionLabel.text = viewModel.description

        titleLabel.text = viewModel.title

        subtitleLabel.text = viewModel.subtitle

        self.thumbnailImageView.image = nil
        //TODO cancel the request if we reuse the cell before it's finished downloading
        if let url = viewModel.thumbnailImageUrl {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .returnCacheDataElseLoad
            Alamofire.request(request).response { [weak self] response in
                guard let strongSelf = self else { return }
                if let data = response.data, let image = UIImage(data: data) {
                    if url == viewModel.thumbnailImageUrl {
                        strongSelf.thumbnailImageView.image = image
                    }
                }
            }
        }
    }

    ///We only add labels, not remove them. For performance
    private func displayDetails(viewModel: TokenListFormatRowViewModel) {
        for each in detailLabels {
            each.text = ""
        }
        let labelsToAddCount = viewModel.details.count - detailLabels.count
        if labelsToAddCount > 0 {
            for _ in 1...labelsToAddCount {
                let label = UILabel()
                label.translatesAutoresizingMaskIntoConstraints = false
                label.textColor = viewModel.subtitleColor
                label.font = viewModel.detailsFont
                detailLabels.append(label)
                detailsRowStack.addArrangedSubview(label)
            }
        }
        for (i, each) in viewModel.details.enumerated() {
            let label = detailLabels[i]
            label.text = each
        }
    }
}

extension TokenListFormatRowView: TokenRowView {
    func configure(tokenHolder: TokenHolder) {
        configure(viewModel: .init(tokenHolder: tokenHolder))
    }
}
