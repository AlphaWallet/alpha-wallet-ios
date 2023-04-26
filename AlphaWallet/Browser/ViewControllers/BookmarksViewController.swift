//
// Created by James Sangalli on 8/12/18.
//

import Foundation
import UIKit
import StatefulViewController
import AlphaWalletFoundation
import Combine

protocol BookmarksViewControllerDelegate: AnyObject {
    func didTapToEdit(bookmark: BookmarkObject, in viewController: BookmarksViewController)
    func didTapToSelect(bookmark: BookmarkObject, in viewController: BookmarksViewController)
    func dismissKeyboard(in viewController: BookmarksViewController)
}

final class BookmarksViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.register(MyDappCell.self)
        tableView.tableHeaderView = headerView
        tableView.separatorStyle = .none
        tableView.allowsSelectionDuringEditing = true
        tableView.delegate = self

        return tableView
    }()
    private lazy var headerView = BookmarksHeaderView()
    private let viewModel: BookmarksViewViewModel
    private lazy var dataSource = makeDataSource()
    private var cancelable = Set<AnyCancellable>()
    private let deleteBookmark = PassthroughSubject<BookmarkObject, Never>()
    private let reorderBookmarks = PassthroughSubject<(from: IndexPath, to: IndexPath), Never>()

    private var browserNavBar: DappBrowserNavigationBar? {
        return navigationController?.navigationBar as? DappBrowserNavigationBar
    }

    weak var delegate: BookmarksViewControllerDelegate?

    init(viewModel: BookmarksViewViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        emptyView = {
            let emptyView = DappsHomeEmptyView()
            emptyView.configure(viewModel: viewModel.emptyViewModel)
            return emptyView
        }()

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view)
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

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset.bottom = keyboardEndFrame.size.height
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        if let _ = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            tableView.contentInset.bottom = 0
        }
    }

    private func bind(viewModel: BookmarksViewViewModel) {
        let input = BookmarksViewModelInput(
            deleteBookmark: deleteBookmark.eraseToAnyPublisher(),
            reorderBookmarks: reorderBookmarks.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.viewState
            .sink { [dataSource, weak self] viewState in
                dataSource.apply(viewState.snapshot, animatingDifferences: viewState.animatingDifferences)
                self?.endLoading()
            }.store(in: &cancelable)
    }

    private func buildTableViewHeader() {
        headerView.delegate = self
        headerView.configure(viewModel: viewModel.headerViewModel)

        let fittingSize = headerView.systemLayoutSizeFitting(.init(width: tableView.frame.size.width, height: 1000))
        headerView.frame = .init(x: 0, y: 0, width: 0, height: fittingSize.height)
        tableView.tableHeaderView = headerView
    }

    private func dismissKeyboard() {
        delegate?.dismissKeyboard(in: self)
    }
}

extension BookmarksViewController: StatefulViewController {
    func hasContent() -> Bool {
        return dataSource.snapshot().numberOfItems > 0
    }
}

extension BookmarksViewController {
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

    public func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        reorderBookmarks.send((from: sourceIndexPath, to: destinationIndexPath))
    }
}

fileprivate extension BookmarksViewController {
    private func makeDataSource() -> BookmarksViewViewModel.DataSource {
        return BookmarksViewViewModel.DataSource(tableView: tableView, cellProvider: { tableView, indexPath, viewModel in
            let cell: MyDappCell = tableView.dequeueReusableCell(for: indexPath)
            cell.configure(viewModel: viewModel)

            return cell
        })
    }
}

extension BookmarksViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let bookmark = dataSource.item(at: indexPath).bookmark
        if tableView.isEditing {
            delegate?.didTapToEdit(bookmark: bookmark, in: self)
        } else {
            dismissKeyboard()
            delegate?.didTapToSelect(bookmark: bookmark, in: self)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let title = R.string.localizable.dappBrowserClearMyDapps()
        let deleteAction = UIContextualAction(style: .destructive, title: title) { [dataSource, deleteBookmark, headerView] _, _, completion in
            let bookmark = dataSource.item(at: indexPath).bookmark
            Task { @MainActor in
                let result = await self.confirm(
                    title: title,
                    message: bookmark.title,
                    okTitle: R.string.localizable.removeButtonTitle(),
                    okStyle: .destructive)

                switch result {
                case .success:
                    deleteBookmark.send(bookmark)

                    var snapshot = dataSource.snapshot()
                    let item = dataSource.item(at: indexPath)
                    snapshot.deleteItems([item])

                    dataSource.apply(snapshot, animatingDifferences: true)

                    if !self.hasContent() {
                        headerView.exitEditMode()
                    }
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

extension BookmarksViewController: BookmarksHeaderViewDelegate {
    func didEnterEditMode(inHeaderView headerView: BookmarksHeaderView) {
        //TODO should this be a state case in the nav bar, but with a flag (associated value?) whether to disable the buttons?
        browserNavBar?.disableButtons()
        tableView.setEditing(true, animated: true)
    }

    func didExitEditMode(inHeaderView headerView: BookmarksHeaderView) {
        //TODO should this be a state case in the nav bar, but with a flag (associated value?) whether to disable the buttons?
        browserNavBar?.enableButtons()
        tableView.setEditing(false, animated: true)
    }
}
