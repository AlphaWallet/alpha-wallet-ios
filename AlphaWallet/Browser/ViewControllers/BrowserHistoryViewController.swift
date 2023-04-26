//
// Created by James Sangalli on 8/12/18.
//

import Foundation
import UIKit
import StatefulViewController
import AlphaWalletFoundation
import Combine

protocol BrowserHistoryViewControllerDelegate: AnyObject {
    func didSelect(history: BrowserHistoryRecord, in viewController: BrowserHistoryViewController)
    func dismissKeyboard(inViewController viewController: BrowserHistoryViewController)
}

final class BrowserHistoryViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.delegate = self
        tableView.tableHeaderView = headerView
        tableView.separatorStyle = .none
        tableView.register(BrowserHistoryCell.self)

        return tableView
    }()
    private let viewModel: BrowserHistoryViewModel
    private lazy var headerView = BrowserHistoryHeaderView()
    private lazy var dataSource = makeDataSource()
    private var cancelable = Set<AnyCancellable>()
    private let deleteRecord = PassthroughSubject<BrowserHistoryViewModel.DeleteRecordAction, Never>()

    weak var delegate: BrowserHistoryViewControllerDelegate?

    init(viewModel: BrowserHistoryViewModel) {
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)
        emptyView = {
            let emptyView = DappsHomeEmptyView()
            let headerViewModel = BrowserHomeHeaderViewModel(title: R.string.localizable.dappBrowserBrowserHistory())
            emptyView.configure(viewModel: .init(headerViewViewModel: headerViewModel, title: R.string.localizable.browserNoHistoryLabelTitle()))
            return emptyView
        }()

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        buildTableViewHeader()
        bind(viewModel: viewModel)
    }

    private func bind(viewModel: BrowserHistoryViewModel) {
        let input = BrowserHistoryViewModelInput(deleteRecord: deleteRecord.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource, weak self] viewState in
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
                self?.endLoading()
            }.store(in: &cancelable)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
            tableView.contentInset.bottom = keyboardEndFrame.size.height
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        if let _ = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue, let _ = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
            tableView.contentInset.bottom = 0
        }
    }

    private func buildTableViewHeader() {
        let headerViewModel = BrowserHomeHeaderViewModel(title: R.string.localizable.dappBrowserBrowserHistory())
        headerView.delegate = self
        headerView.configure(viewModel: headerViewModel)
        let fittingSize = headerView.systemLayoutSizeFitting(.init(width: tableView.frame.size.width, height: 1000))
        headerView.frame = .init(x: 0, y: 0, width: 0, height: fittingSize.height)
        tableView.tableHeaderView = headerView
    }
}

extension BrowserHistoryViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension BrowserHistoryViewController: UITableViewDelegate {
    //Hide the header
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    //Hide the footer
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.dismissKeyboard(inViewController: self)

        delegate?.didSelect(history: dataSource.item(at: indexPath).history, in: self)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.removeButtonTitle()
        let deleteAction = UIContextualAction(style: .destructive, title: title) { [dataSource, deleteRecord] _, _, completion in
            let history = dataSource.item(at: indexPath).history
            Task { @MainActor in
                let result = await self.confirm(
                    title: R.string.localizable.browserHistoryConfirmDeleteTitle(),
                    message: history.url.absoluteString,
                    okTitle: R.string.localizable.removeButtonTitle(),
                    okStyle: .destructive)

                switch result {
                case .success:
                    deleteRecord.send(.record(history))

                    var snapshot = dataSource.snapshot()
                    let item = dataSource.item(at: indexPath)
                    snapshot.deleteItems([item])

                    dataSource.apply(snapshot, animatingDifferences: true)

                    completion(true)
                case .failure:
                    completion(false)
                }
            }
        }

        deleteAction.backgroundColor = Configuration.Color.Semantic.dangerBackground
        deleteAction.image = R.image.hideToken()

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }
}

extension BrowserHistoryViewController: BrowserHistoryHeaderViewDelegate {
    func didTapClearAll(in headerView: BrowserHistoryHeaderView) {
        UIAlertController.alert(
                title: R.string.localizable.dappBrowserClearHistory(),
                message: R.string.localizable.dappBrowserClearHistoryPrompt(),
                alertButtonTitles: [R.string.localizable.clearButtonTitle(), R.string.localizable.cancel()],
                alertButtonStyles: [.destructive, .cancel],
                viewController: self,
                completion: { [deleteRecord] buttonIndex in
                    guard buttonIndex == 0 else { return }
                    deleteRecord.send(.all)
                })
    }
}

fileprivate extension BrowserHistoryViewController {
    private func makeDataSource() -> BrowserHistoryViewModel.DataSource {
        return BrowserHistoryViewModel.DataSource(tableView: tableView, cellProvider: { tableView, indexPath, viewModel in
            let cell: BrowserHistoryCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        })
    }
}
