//
//  PriceAlertsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit
import AlphaWalletFoundation
import StatefulViewController
import Combine

protocol PriceAlertsViewControllerDelegate: AnyObject {
    func editAlertSelected(in viewController: PriceAlertsViewController, alert: PriceAlert)
    func addAlertSelected(in viewController: PriceAlertsViewController)
}

class PriceAlertsViewController: UIViewController {
    private let viewModel: PriceAlertsViewModel
    private lazy var dataSource = makeDataSource()
    private lazy var tableView: UITableView = {
        var tableView = UITableView.buildGroupedTableView()
        tableView.register(PriceAlertTableViewCell.self)
        tableView.delegate = self

        return tableView
    }()
    private let updateAlert = PassthroughSubject<(value: Bool, indexPath: IndexPath), Never>()
    private let removeAlert = PassthroughSubject<IndexPath, Never>()
    private var cancelable = Set<AnyCancellable>()

    private lazy var addNotificationView: AddHideTokensView = {
        let view = AddHideTokensView()
        view.delegate = self

        return view
    }()
    weak var delegate: PriceAlertsViewControllerDelegate?

    init(viewModel: PriceAlertsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let stackView = [
            addNotificationView,
            UIView.separator(),
            tableView
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view),
            addNotificationView.heightAnchor.constraint(equalToConstant: DataEntry.Metric.Tokens.Filter.height)
        ])
        
        emptyView = EmptyView.priceAlertsEmptyView()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: PriceAlertsViewModel) {
        let input = PriceAlertsViewModelInput(
            updateAlert: updateAlert.eraseToAnyPublisher(),
            removeAlert: removeAlert.eraseToAnyPublisher())

        let outout = viewModel.transform(input: input)
        outout.viewState
            .sink { [weak self, dataSource, addNotificationView] viewState in
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
                addNotificationView.configure(viewModel: viewState.addNewAlertViewModel)
                self?.endLoading()
            }.store(in: &cancelable)
    }
}

extension PriceAlertsViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension PriceAlertsViewController {
    private func makeDataSource() -> PriceAlertsViewModel.DataSource {
        PriceAlertsViewModel.DataSource(tableView: tableView) { [weak self] tableView, indexPath, viewModel -> PriceAlertTableViewCell in
            guard let strongSelf = self else { return PriceAlertTableViewCell() }
            
            let cell: PriceAlertTableViewCell = tableView.dequeueReusableCell(for: indexPath)
            cell.delegate = strongSelf
            cell.configure(viewModel: viewModel)

            return cell
        }
    }
}

extension PriceAlertsViewController: PriceAlertTableViewCellDelegate {
    func cell(_ cell: PriceAlertTableViewCell, didToggle value: Bool, indexPath: IndexPath) {
        updateAlert.send((value, indexPath))
    }
}

extension PriceAlertsViewController: UITableViewDelegate {

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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        delegate?.editAlertSelected(in: self, alert: dataSource.item(at: indexPath).alert)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        return trailingSwipeActionsConfiguration(forRowAt: indexPath)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    private func trailingSwipeActionsConfiguration(forRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.delete()
        let hideAction = UIContextualAction(style: .destructive, title: title) { [removeAlert, dataSource] (_, _, completion) in
            var snapshot = dataSource.snapshot()

            let item = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[indexPath.section])[indexPath.row]
            snapshot.deleteItems([item])

            dataSource.apply(snapshot, animatingDifferences: true)

            removeAlert.send(indexPath)

            completion(true)
        }

        hideAction.backgroundColor = Configuration.Color.Semantic.dangerBackground
        hideAction.image = R.image.hideToken()
        let configuration = UISwipeActionsConfiguration(actions: [hideAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }
}

extension PriceAlertsViewController: AddHideTokensViewDelegate {
    func view(_ view: AddHideTokensView, didSelectAddHideTokensButton sender: UIButton) {
        delegate?.addAlertSelected(in: self)
    }
}
