//
//  PriceAlertsPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit
import AlphaWalletFoundation

protocol PriceAlertsPageViewDelegate: class {
    func editAlertSelected(in view: PriceAlertsPageView, alert: PriceAlert)
    func addAlertSelected(in view: PriceAlertsPageView)
    func removeAlert(in view: PriceAlertsPageView, indexPath: IndexPath)
    func updateAlert(in view: PriceAlertsPageView, value: Bool, indexPath: IndexPath)
}

class PriceAlertsPageView: UIView, PageViewType {
    var title: String { viewModel.title }

    var rightBarButtonItem: UIBarButtonItem?

    private var viewModel: PriceAlertsPageViewModel

    private lazy var tableView: UITableView = {
        var tableView = UITableView()
        tableView.register(PriceAlertTableViewCell.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = viewModel.backgroundColor
        tableView.estimatedRowHeight = Metrics.anArbitraryRowHeightSoAutoSizingCellsWorkIniOS10
        tableView.tableFooterView = .tableFooterToRemoveEmptyCellSeparators()

        return tableView
    }()

    private lazy var statefulView: StatefulView<UITableView> = {
        return .init(subview: tableView)
    }()

    private lazy var addNotificationView: AddHideTokensView = {
        let view = AddHideTokensView()
        view.delegate = self
        view.configure(viewModel: viewModel.addNewAlertViewModel)

        return view
    }()
    weak var delegate: PriceAlertsPageViewDelegate?

    init(viewModel: PriceAlertsPageViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        let stackView = [
            addNotificationView.embededWithSeparator(top: 0),
            statefulView
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraintSafeArea(to: self),
            addNotificationView.heightAnchor.constraint(equalToConstant: DataEntry.Metric.Tokens.Filter.height)
        ])
        
        statefulView.emptyView = EmptyView.activitiesEmptyView() 
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: PriceAlertsPageViewModel) {
        self.viewModel = viewModel

        reloadData()
        statefulView.endLoading()
    }

    deinit {
        statefulView.resetStatefulStateToReleaseObjectToAvoidMemoryLeak()
    }

    func reloadData() {
        tableView.reloadData()
    } 
}

extension PriceAlertsPageView: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.alerts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PriceAlertTableViewCell = tableView.dequeueReusableCell(for: indexPath)
        cell.delegate = self
        cell.configure(viewModel: .init(alert: viewModel.alerts[indexPath.row]))

        return cell
    }
    
}

extension PriceAlertsPageView: PriceAlertTableViewCellDelegate {
    func cell(_ cell: PriceAlertTableViewCell, didToggle value: Bool, indexPath: IndexPath) {
        delegate?.updateAlert(in: self, value: value, indexPath: indexPath)
    }
}

extension PriceAlertsPageView: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let alert = viewModel.alerts[indexPath.row]

        delegate?.editAlertSelected(in: self, alert: alert)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return trailingSwipeActionsConfiguration(forRowAt: indexPath)
    }

    private func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.delete()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [weak self] (_, _, completionHandler) in
            guard let strongSelf = self else { return }
            
            strongSelf.viewModel.removeAlert(indexPath: indexPath)
            strongSelf.tableView.deleteRows(at: [indexPath], with: .automatic)
            strongSelf.statefulView.endLoading()
            // NOTE: small delay for correct remove animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                strongSelf.delegate?.removeAlert(in: strongSelf, indexPath: indexPath)
            }

            completionHandler(true)
        }

        hideAction.backgroundColor = R.color.danger()
        hideAction.image = R.image.hideToken()
        let configuration = UISwipeActionsConfiguration(actions: [hideAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }
}

extension PriceAlertsPageView: AddHideTokensViewDelegate {
    func view(_ view: AddHideTokensView, didSelectAddHideTokensButton sender: UIButton) {
        delegate?.addAlertSelected(in: self)
    }
}

protocol PriceAlertTableViewCellDelegate: class {
    func cell(_ cell: PriceAlertsPageView.PriceAlertTableViewCell, didToggle value: Bool, indexPath: IndexPath)
}

extension PriceAlertsPageView {

    struct PriceAlertTableViewCellViewModel {
        let titleAttributedString: NSAttributedString
        let icon: UIImage?
        let isSelected: Bool

        init(alert: PriceAlert) {
            titleAttributedString = .init(string: alert.title, attributes: [
                .font: Fonts.regular(size: 17),
                .foregroundColor: Colors.black
            ])
            icon = alert.icon
            isSelected = alert.isEnabled
        }
    }

    class PriceAlertTableViewCell: UITableViewCell {
        private lazy var iconImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false

            return imageView
        }()

        private lazy var titleLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false

            return label
        }()

        private lazy var switchButton: UISwitch = {
            let button = UISwitch()
            button.translatesAutoresizingMaskIntoConstraints = false

            return button
        }()

        weak var delegate: PriceAlertTableViewCellDelegate?

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            separatorInset = .zero

            let stackView = [
                .spacerWidth(16),
                iconImageView,
                .spacerWidth(16),
                titleLabel,
                .spacerWidth(16, flexible: true),
                switchButton,
                .spacerWidth(16),
            ].asStackView(axis: .horizontal, alignment: .center)
            stackView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(stackView)

            NSLayoutConstraint.activate([
                iconImageView.heightAnchor.constraint(equalToConstant: 18),
                iconImageView.widthAnchor.constraint(equalToConstant: 18),
                stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 14, left: 0, bottom: 14, right: 0))
            ])

            switchButton.addTarget(self, action: #selector(toggleSelectionState), for: .valueChanged)
        }

        required init?(coder: NSCoder) {
            return nil
        }

        func configure(viewModel: PriceAlertTableViewCellViewModel) {
            iconImageView.image = viewModel.icon
            titleLabel.attributedText = viewModel.titleAttributedString
            switchButton.isEnabled = viewModel.isSelected
        }

        @objc private func toggleSelectionState(_ sender: UISwitch) {
            guard let indexPath = indexPath else { return }
            delegate?.cell(self, didToggle: sender.isEnabled, indexPath: indexPath)
        }
    }
}
