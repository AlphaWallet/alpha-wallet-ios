// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol LocalesCoordinatorDelegate: class {
    func didSelect(locale: AppLocale, in coordinator: LocalesCoordinator)
}

class LocalesCoordinator: Coordinator {
    private var config: Config

    var coordinators: [Coordinator] = []

    lazy var localesViewController: LocalesViewController = {
        let locales: [AppLocale] = [
            .system,
            .english,
            .simplifiedChinese,
            .spanish,
            .korean,
            .japanese
        ]
        let controller = LocalesViewController()
        controller.configure(viewModel: LocalesViewModel(locales: locales, selectedLocale: AppLocale(id: Config.getLocale())))
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
        Config.setLocale(locale)
        delegate?.didSelect(locale: locale, in: self)
    }
}

