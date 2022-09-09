// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

extension TokenScriptOverrides {
    //TODO: Not good to require to use safeTitleInPluralForm. Easy to access wrong var
    ///Use this instead of shortTitleInPluralForm directly
    var safeShortTitleInPluralForm: String? {
        let s = shortTitleInPluralForm
        if s == Constants.katNameFallback {
            return R.string.localizable.katTitlecase()
        } else {
            return s
        }
    }
}