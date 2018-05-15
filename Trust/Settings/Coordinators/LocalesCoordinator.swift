// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol LocalesCoordinatorDelegate: class {
    func didSelect(locale: AppLocale, in coordinator: LocalesCoordinator)
}

class LocalesCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    var config: Config

    lazy var localesViewController: LocalesViewController = {
        let locales: [AppLocale] = [
            .system,
            .english,
            .simplifiedChinese,
            .spanish,
        ]
        let controller = LocalesViewController()
        controller.configure(viewModel: LocalesViewModel(locales: locales, selectedLocale: AppLocale(id: config.locale)))
        controller.delegate = self
        return controller
    }()
    weak var delegate: LocalesCoordinatorDelegate?

    init(config: Config) {
        self.config = config
    }

    func start() {
    }
}

extension LocalesCoordinator: LocalesViewControllerDelegate {
    func didSelect(locale: AppLocale, in viewController: LocalesViewController) {
        config.locale = locale.id
        delegate?.didSelect(locale: locale, in: self)
    }
}

