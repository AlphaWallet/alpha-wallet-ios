//
// Created by James Sangalli on 8/12/18.
//

import Foundation
import UIKit

protocol DiscoverDappsViewControllerDelegate: class {
    func didTap(dapp: Dapp, inViewController viewController: DiscoverDappsViewController)
    func didAdd(dapp: Dapp, inViewController viewController: DiscoverDappsViewController)
    func didRemove(dapp: Dapp, inViewController viewController: DiscoverDappsViewController)
    func dismissKeyboard(inViewController viewController: DiscoverDappsViewController)
}

class DiscoverDappsViewController: UIViewController {

    lazy private var headerBoxView = BoxView(view: DappsHomeHeaderView())
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var viewModel = DiscoverDappsViewControllerViewModel()
    private var bookmarksStore: BookmarksStore
    weak var delegate: DiscoverDappsViewControllerDelegate?

    init(bookmarksStore: BookmarksStore) {
        self.bookmarksStore = bookmarksStore
        super.init(nibName: nil, bundle: nil)

        tableView.register(DiscoverDappCell.self)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.tableHeaderView = headerBoxView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsConstraint(to: view)
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

    func configure(viewModel: DiscoverDappsViewControllerViewModel) {
        self.viewModel = viewModel

        tableView.backgroundColor = viewModel.backgroundColor

        resizeTableViewHeader()
        tableView.reloadData()
    }

    private func resizeTableViewHeader() {
        let headerViewModel = DappsHomeHeaderViewViewModel(title: R.string.localizable.discoverDappsButtonImageLabel())
        headerBoxView.view.configure(viewModel: headerViewModel)
        headerBoxView.backgroundColor = headerViewModel.backgroundColor
        headerBoxView.insets = .init(top: 50, left: 0, bottom: 50, right: 0)
        let fittingSize = headerBoxView.systemLayoutSizeFitting(.init(width: tableView.frame.size.width, height: 1000))
        headerBoxView.frame = .init(x: 0, y: 0, width: 0, height: fittingSize.height)
        tableView.tableHeaderView = headerBoxView
    }

    private func dismissKeyboard() {
        delegate?.dismissKeyboard(inViewController: self)
    }
}

extension DiscoverDappsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.dappCategories.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: DiscoverDappCell = tableView.dequeueReusableCell(for: indexPath)
        let dapp = viewModel.dappCategories[indexPath.section].dapps[indexPath.row]
        cell.configure(viewModel: .init(bookmarksStore: bookmarksStore, dapp: dapp))
        cell.delegate = self
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.dappCategories[section].dapps.count
    }
}

extension DiscoverDappsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        dismissKeyboard()
        let dapp = viewModel.dappCategories[indexPath.section].dapps[indexPath.row]
        delegate?.didTap(dapp: dapp, inViewController: self)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = viewModel.dappCategories[section].name
        return SectionHeaderView(title: title)
    }
}

extension DiscoverDappsViewController: DiscoverDappCellDelegate {
    func onAdd(dapp: Dapp, inCell cell: DiscoverDappCell) {
        bookmarksStore.add(bookmarks: [.init(url: dapp.url, title: dapp.name)])
        tableView.reloadData()
        delegate?.didAdd(dapp: dapp, inViewController: self)
    }

    func onRemove(dapp: Dapp, inCell cell: DiscoverDappCell) {
        bookmarksStore.delete(bookmarks: [.init(url: dapp.url, title: dapp.name)])
        tableView.reloadData()
        delegate?.didRemove(dapp: dapp, inViewController: self)
    }
}

private class SectionHeaderView: UIView {
    private let label = UILabel()

    var title: String {
        didSet {
            update(title: title)
        }
    }

    init(title: String) {
        self.title = title
        super.init(frame: .zero)

        update(title: title)

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.anchorsConstraint(to: self, edgeInsets: .init(top: 12, left: 31, bottom: 10, right: 0))
        ])

        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure() {
        backgroundColor = Colors.appWhite

        label.textColor = UIColor(red: 77, green: 77, blue: 77)
        label.font = Fonts.regular(size: 10)
    }

    private func update(title: String) {
        label.text = title.localizedUppercase
    }
}
