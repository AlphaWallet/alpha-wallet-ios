// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

protocol LocalesViewControllerDelegate: AnyObject {
    func didSelect(locale: AppLocale, in viewController: LocalesViewController)
}

class LocalesViewController: UIViewController {
    private lazy var tableView: UITableView = {
        let tableView = UITableView.buildGroupedTableView()
        tableView.delegate = self
        tableView.register(LocaleViewCell.self)

        return tableView
    }()
    private var viewModel: LocalesViewModel?

    weak var delegate: LocalesViewControllerDelegate?

    init() {
        super.init(nibName: nil, bundle: nil)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.anchorsIgnoringBottomSafeArea(to: view)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    func configure(viewModel: LocalesViewModel) {
        self.viewModel = viewModel
        tableView.dataSource = self
        title = viewModel.title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LocalesViewController: UITableViewDelegate, UITableViewDataSource {
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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.locales.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: LocaleViewCell = tableView.dequeueReusableCell(for: indexPath)
        if let viewModel = viewModel {
            let locale = viewModel.locale(for: indexPath)
            let cellViewModel = LocaleViewModel(locale: locale, selected: viewModel.isLocaleSelected(locale))
            cell.configure(viewModel: cellViewModel)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        reflectTemporarySelection(atIndexPath: indexPath)

        tableView.deselectRow(at: indexPath, animated: true)
        guard let viewModel = viewModel else { return }
        let locale = viewModel.locale(for: indexPath)

        //Dispatch so the updated selection checkbox can be shown to the user before closing the screen
        DispatchQueue.main.async {
            self.delegate?.didSelect(locale: locale, in: self)
        }
    }

    private func reflectTemporarySelection(atIndexPath indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            cell.accessoryType = LocaleViewCell.selectionAccessoryType.selected
        }
        guard let viewModel = viewModel else { return }
        for (index, locale) in viewModel.locales.enumerated() where viewModel.isLocaleSelected(locale) {
            guard let cell = tableView.cellForRow(at: .init(row: index, section: indexPath.section)) else { break }
            cell.accessoryType = LocaleViewCell.selectionAccessoryType.unselected
            break
        }
    }
}
