// Copyright © 2018 Stormbird PTE. LTD. import Foundation

import UIKit
import Alamofire

protocol ImportTicketViewControllerDelegate: class {
    func didPressDone(in viewController: ImportTicketViewController)
    func didPressImport(in viewController: ImportTicketViewController)
}

class ImportTicketViewController: UIViewController {
    weak var delegate: ImportTicketViewControllerDelegate?
    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
    let ticketView = TicketRowView()
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
    var viewModel: ImportTicketViewControllerViewModel?
    var query: String?
    var parameters: Parameters?
    var signedOrder: SignedOrder?
    var tokenObject: TokenObject?

    init() {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .clear

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ticketView)

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
            ticketView,
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

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            separator1.heightAnchor.constraint(equalToConstant: 1),
            separator1.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            separator1.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

            separator2.heightAnchor.constraint(equalToConstant: 1),
            separator2.leadingAnchor.constraint(equalTo: ticketView.background.leadingAnchor),
            separator2.trailingAnchor.constraint(equalTo: ticketView.background.trailingAnchor),

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

            statusLabel.widthAnchor.constraint(equalTo: ticketView.widthAnchor, constant: -20),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ImportTicketViewControllerViewModel) {
        self.viewModel = viewModel
        if let viewModel = self.viewModel {
            view.backgroundColor = viewModel.backgroundColor

            header.configure(title: viewModel.headerTitle)

            ticketView.configure(viewModel: .init())

            ticketView.isHidden = !viewModel.showTicketRow

            ticketView.stateLabel.isHidden = true

            ticketView.ticketCountLabel.text = viewModel.ticketCount
            ticketView.titleLabel.text = viewModel.title
            ticketView.venueLabel.text = viewModel.venue
            ticketView.dateLabel.text = viewModel.date
            ticketView.seatRangeLabel.text = viewModel.seatRange
            ticketView.cityLabel.text = viewModel.city
            ticketView.categoryLabel.text = viewModel.category
            ticketView.timeLabel.text = viewModel.time
            ticketView.teamsLabel.text = viewModel.teams

            ticketView.dateImageView.isHidden = !viewModel.showTicketRowIcons
            ticketView.seatRangeImageView.isHidden = !viewModel.showTicketRowIcons
            ticketView.categoryImageView.isHidden = !viewModel.showTicketRowIcons

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

            dollarCostLabel.textColor = viewModel.dollarCostLabelColor
            dollarCostLabel.font = viewModel.dollarCostLabelFont
            dollarCostLabel.textAlignment = .center
            dollarCostLabel.text = viewModel.dollarCostLabelText
            dollarCostLabel.backgroundColor = viewModel.dollarCostLabelBackgroundColor
            dollarCostLabel.layer.masksToBounds = true
            dollarCostLabel.isHidden = !viewModel.showDollarCostLabel

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

    class PaddedLabel: UILabel {
        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(width: size.width + 30, height: size.height + 10)
        }
    }
}

