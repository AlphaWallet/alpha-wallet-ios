// Copyright © 2018 Stormbird PTE. LTD.

import TrustKeystore
import UIKit

protocol LocalesViewControllerDelegate: class {
    func didSelect(locale: AppLocale, in viewController: LocalesViewController)
}

class LocalesViewController: UIViewController {
    let headerHeight = CGFloat(70)
    weak var delegate: LocalesViewControllerDelegate?
    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
    let tableView = UITableView(frame: .zero, style: .plain)
    var viewModel: LocalesViewModel?
    private var balances: [Address: Balance?] = [:]

    init() {
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = Colors.appWhite
        tableView.rowHeight = 80
        tableView.tableHeaderView = header
        tableView.register(LocaleViewCell.self, forCellReuseIdentifier: LocaleViewCell.identifier)
        roundedBackground.addSubview(tableView)

        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: headerHeight),

            tableView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    func configure(viewModel: LocalesViewModel) {
        self.viewModel = viewModel
        tableView.dataSource = self
        header.configure(title: viewModel.title)
        header.frame.size.height = headerHeight
        tableView.tableHeaderView = header
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LocalesViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.locales.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: LocaleViewCell.identifier, for: indexPath) as! LocaleViewCell
        if let viewModel = viewModel {
            let locale = viewModel.locale(for: indexPath)
            let cellViewModel = LocaleViewModel(locale: locale, selected: viewModel.isLocaleSelected(locale))
            cell.configure(viewModel: cellViewModel)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let viewModel = viewModel else { return }
        let locale = viewModel.locale(for: indexPath)
        delegate?.didSelect(locale: locale, in: self)
    }
}
