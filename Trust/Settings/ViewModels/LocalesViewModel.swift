// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import TrustKeystore

struct LocalesViewModel {
    let locales: [AppLocale]
    let selectedLocale: AppLocale

    var title: String {
        return R.string.localizable.settingsLanguageButtonTitle()
    }

    init(locales: [AppLocale], selectedLocale: AppLocale) {
        self.locales = locales
        self.selectedLocale = selectedLocale
    }

    func locale(for indexPath: IndexPath) -> AppLocale  {
        return locales[indexPath.row]
    }

    func isLocaleSelected(_ locale: AppLocale) -> Bool {
        return locale.id == selectedLocale.id
    }
}
