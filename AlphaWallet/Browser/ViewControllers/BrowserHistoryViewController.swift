//
// Created by James Sangalli on 8/12/18.
//

import Foundation
import UIKit
import StatefulViewController

protocol BrowserHistoryViewControllerDelegate: class {
    func didSelect(history: History, inViewController controller: BrowserHistoryViewController)
    func clearHistory(inViewController viewController: BrowserHistoryViewController)
    func dismissKeyboard(inViewController viewController: BrowserHistoryViewController)
}

final class BrowserHistoryViewController: UIViewController {
    private let store: HistoryStore
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var viewModel: HistoriesViewModel
    lazy private var headerView = BrowserHistoryViewControllerHeaderView()

    weak var delegate: BrowserHistoryViewControllerDelegate?

    init(store: HistoryStore) {
        self.store = store
        self.viewModel = HistoriesViewModel(store: store)

        super.init(nibName: nil, bundle: nil)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = headerView
        tableView.separatorStyle = .none
        tableView.register(BrowserHistoryCell.self, forCellReuseIdentifier: BrowserHistoryCell.identifier)
        view.addSubview(tableView)
        emptyView = {
            let emptyView = DappsHomeEmptyView()
            let headerViewModel = DappsHomeHeaderViewViewModel(title: R.string.localizable.dappBrowserBrowserHistory())
            emptyView.configure(viewModel: .init(headerViewViewModel: headerViewModel, title: R.string.localizable.browserNoHistoryLabelTitle()))
            return emptyView
        }()

        NSLayoutConstraint.activate([
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupInitialViewState()

        fetch()
    }

    func fetch() {
        tableView.reloadData()
    }

    func configure(viewModel: HistoriesViewModel) {
        tableView.backgroundColor = Colors.appWhite

        resizeTableViewHeader()
        tableView.reloadData()
        endLoading()
    }

    private func resizeTableViewHeader() {
        let headerViewModel = DappsHomeHeaderViewViewModel(title: R.string.localizable.dappBrowserBrowserHistory())
        headerView.delegate = self
        headerView.configure(viewModel: headerViewModel)
        let fittingSize = headerView.systemLayoutSizeFitting(.init(width: tableView.frame.size.width, height: 1000))
        headerView.frame = .init(x: 0, y: 0, width: 0, height: fittingSize.height)
        tableView.tableHeaderView = headerView
    }
}

extension BrowserHistoryViewController: StatefulViewController {
    func hasContent() -> Bool {
        return viewModel.hasContent
    }
}

extension BrowserHistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.numberOfRows
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BrowserHistoryCell.identifier, for: indexPath) as! BrowserHistoryCell
        cell.configure(viewModel: .init(history: viewModel.item(for: indexPath)))
        return cell
    }
}

extension BrowserHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        delegate?.dismissKeyboard(inViewController: self)
        let history = viewModel.item(for: indexPath)
        delegate?.didSelect(history: history, inViewController: self)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let history = viewModel.item(for: indexPath)
            confirm(
                    title: R.string.localizable.browserHistoryConfirmDeleteTitle(),
                    message: history.url,
                    okTitle: R.string.localizable.removeButtonTitle(),
                    okStyle: .destructive
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.store.delete(histories: [history])
                    //TODO improve animation
                    self?.tableView.reloadData()
                    self?.endLoading()
                case .failure: break
                }
            }
        }
    }
}

extension BrowserHistoryViewController: BrowserHistoryViewControllerHeaderViewDelegate {
    func didTapClearAll(inHeaderView headerView: BrowserHistoryViewControllerHeaderView) {
        UIAlertController.alert(
                title: R.string.localizable.dappBrowserClearHistory(),
                message: R.string.localizable.dappBrowserClearHistoryPrompt(),
                alertButtonTitles: [R.string.localizable.clearButtonTitle(), R.string.localizable.cancel()],
                alertButtonStyles: [.destructive, .cancel],
                viewController: self,
                completion: { [weak self] buttonIndex in
                    guard let strongSelf = self else { return }
                    if buttonIndex == 0 {
                        strongSelf.delegate?.clearHistory(inViewController: strongSelf)
                    }
                })
    }
}
