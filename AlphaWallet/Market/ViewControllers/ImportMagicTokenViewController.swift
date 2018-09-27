// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Alamofire

protocol ImportMagicTokenViewControllerDelegate: class, CanOpenURL {
    func didPressDone(in viewController: ImportMagicTokenViewController)
    func didPressImport(in viewController: ImportMagicTokenViewController)
}

class ImportMagicTokenViewController: UIViewController, OptionalTokenVerifiableStatusViewController {
    enum State {
        case ready(ImportMagicTokenViewControllerViewModel)
        case notReady
    }

    let config: Config
    weak var delegate: ImportMagicTokenViewControllerDelegate?
    let roundedBackground = RoundedBackground()
    let header = TokensCardViewControllerTitleHeader()
    let tokenCardRowView = TokenCardRowView()
    let statusLabel = UILabel()
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    var costStackView: UIStackView?
    let ethCostLabelLabel = UILabel()
    let ethCostLabel = UILabel()
    let dollarCostLabelLabel = UILabel()
    let dollarCostLabel = PaddedLabel()
    let buttonSeparator = UIView()
    let actionButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)
    private var viewModel: ImportMagicTokenViewControllerViewModel?
    var contract: String? {
        didSet {
            guard url != nil else { return }
            updateNavigationRightBarButtons(isVerified: isContractVerified, hasShowInfoButton: false)
        }
    }
    var url: URL? {
        didSet {
            updateNavigationRightBarButtons(isVerified: true, hasShowInfoButton: false)
        }
    }
    var state: State {
        if let viewModel = viewModel {
            return .ready(viewModel)
        } else {
            return .notReady
        }
    }

    init(config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .clear

        tokenCardRowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tokenCardRowView)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        ethCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        ethCostLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabelLabel.translatesAutoresizingMaskIntoConstraints = false
        dollarCostLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator1 = UIView()
        separator1.backgroundColor = UIColor(red: 230, green: 230, blue: 230)

        let separator2 = UIView()
        separator2.backgroundColor = UIColor(red: 230, green: 230, blue: 230)

        costStackView = [
            ethCostLabelLabel,
            .spacer(height: 7),
            separator1,
            .spacer(height: 7),
            ethCostLabel,
            .spacer(height: 7),
            separator2,
            .spacer(height: 7),
            dollarCostLabelLabel,
            .spacer(height: 3),
            dollarCostLabel,
        ].asStackView(axis: .vertical, alignment: .center)
        costStackView?.translatesAutoresizingMaskIntoConstraints = false

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        let buttonsStackView = [actionButton, cancelButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            header,
            .spacer(height: 1),
            tokenCardRowView,
            .spacer(height: 1),
            activityIndicator,
            .spacer(height: 14),
            statusLabel,
            .spacer(height: 20),
            costStackView!,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        buttonSeparator.translatesAutoresizingMaskIntoConstraints = false
        buttonSeparator.backgroundColor = Colors.appLightButtonSeparator
        footerBar.addSubview(buttonSeparator)

        let separatorThickness = CGFloat(1)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 90),

            tokenCardRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenCardRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator1.heightAnchor.constraint(equalToConstant: 1),
            separator1.leadingAnchor.constraint(equalTo: tokenCardRowView.background.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: tokenCardRowView.background.trailingAnchor),

            separator2.heightAnchor.constraint(equalToConstant: 1),
            separator2.leadingAnchor.constraint(equalTo: tokenCardRowView.background.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: tokenCardRowView.background.trailingAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            buttonSeparator.leadingAnchor.constraint(equalTo: actionButton.trailingAnchor, constant: -separatorThickness / 2),
            buttonSeparator.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: separatorThickness / 2),
            buttonSeparator.topAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: 8),
            buttonSeparator.bottomAnchor.constraint(equalTo: buttonsStackView.bottomAnchor, constant: -8),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            statusLabel.widthAnchor.constraint(equalTo: tokenCardRowView.widthAnchor, constant: -20),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ImportMagicTokenViewControllerViewModel) {
        self.viewModel = viewModel
        if let viewModel = self.viewModel {
            view.backgroundColor = viewModel.backgroundColor

            header.configure(title: viewModel.headerTitle)

            tokenCardRowView.configure(viewModel: ImportMagicTokenCardRowViewModel(importMagicTokenViewControllerViewModel: viewModel))

            tokenCardRowView.isHidden = !viewModel.showTokenRow
            tokenCardRowView.stateLabel.isHidden = true

            statusLabel.textColor = viewModel.statusColor
            statusLabel.font = viewModel.statusFont
            statusLabel.textAlignment = .center
            statusLabel.text = viewModel.statusText
            statusLabel.numberOfLines = 0

            costStackView?.isHidden = !viewModel.showCost

            ethCostLabelLabel.textColor = viewModel.ethCostLabelLabelColor
            ethCostLabelLabel.font = viewModel.ethCostLabelLabelFont
            ethCostLabelLabel.textAlignment = .center
            ethCostLabelLabel.text = viewModel.ethCostLabelLabelText

            ethCostLabel.textColor = viewModel.ethCostLabelColor
            ethCostLabel.font = viewModel.ethCostLabelFont
            ethCostLabel.textAlignment = .center
            ethCostLabel.text = viewModel.ethCostLabelText

            dollarCostLabelLabel.textColor = viewModel.dollarCostLabelLabelColor
            dollarCostLabelLabel.font = viewModel.dollarCostLabelLabelFont
            dollarCostLabelLabel.textAlignment = .center
            dollarCostLabelLabel.text = viewModel.dollarCostLabelLabelText
            dollarCostLabelLabel.isHidden = viewModel.hideDollarCost

            dollarCostLabel.textColor = viewModel.dollarCostLabelColor
            dollarCostLabel.font = viewModel.dollarCostLabelFont
            dollarCostLabel.textAlignment = .center
            dollarCostLabel.text = viewModel.dollarCostLabelText
            dollarCostLabel.backgroundColor = viewModel.dollarCostLabelBackgroundColor
            dollarCostLabel.layer.masksToBounds = true
            dollarCostLabel.isHidden = viewModel.hideDollarCost

            activityIndicator.color = viewModel.activityIndicatorColor

            if viewModel.showActivityIndicator {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }

            actionButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
            actionButton.backgroundColor = viewModel.buttonBackgroundColor
            actionButton.titleLabel?.font = viewModel.buttonFont
            actionButton.setTitle(viewModel.actionButtonTitle, for: .normal)

            cancelButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
            cancelButton.backgroundColor = viewModel.buttonBackgroundColor
            cancelButton.titleLabel?.font = viewModel.buttonFont
            cancelButton.setTitle(viewModel.cancelButtonTitle, for: .normal)

            actionButton.isHidden = !viewModel.showActionButton
            buttonSeparator.isHidden = !viewModel.showActionButton

            updateNavigationRightBarButtons(isVerified: isContractVerified, hasShowInfoButton: false)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        //We can't use height / 2 because for some unknown reason, dollarCostLabel still has a zero height here
//        dollarCostLabel.layer.cornerRadius = dollarCostLabel.frame.size.height / 2
        dollarCostLabel.layer.cornerRadius = 18
    }

    @objc func actionTapped() {
        delegate?.didPressImport(in: self)
    }

    @objc func cancel() {
        if let delegate = delegate {
            delegate.didPressDone(in: self)
        } else {
            dismiss(animated: true)
        }
    }

    func showContractWebPage() {
        guard let contract = contract else { return }
        if case .main = config.server {
            guard let url = url else { return }
            delegate?.didPressViewContractWebPage(url, in: self)
        } else if case .ropsten = config.server {
            guard let url = URL(string: Constants.ropstenEtherscanContractDetailsWebPageURL + contract) else { return }
            delegate?.didPressViewContractWebPage(url, in: self)
        } else if case .rinkeby = config.server {
            guard let url = URL(string: Constants.rinkebyEtherscanAPI + contract) else { return }
            delegate?.didPressViewContractWebPage(url, in: self)
        } else if case .kovan = config.server {
            guard let url = URL(string: Constants.kovanEtherscanContractDetailsWebPageURL + contract) else { return }
            delegate?.didPressViewContractWebPage(url, in: self)
        } else {
            delegate?.didPressViewContractWebPage(forContract: contract, in: self)
        }
    }

    //Just for protocol conformance. Do nothing
    func showInfo() {
    }

    class PaddedLabel: UILabel {
        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(width: size.width + 30, height: size.height + 10)
        }
    }
}

