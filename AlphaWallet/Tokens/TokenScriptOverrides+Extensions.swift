// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import AlphaWalletTokenScript

extension TokenScriptOverrides {
    //TODO: Not good to require to use safeTitleInPluralForm. Easy to access wrong var
    ///Use this instead of shortTitleInPluralForm directly
    var safeShortTitleInPluralForm: String? {
        let s = shortTitleInPluralForm
        if s == AlphaWalletTokenScript.Constants.katNameFallback {
            return R.string.localizable.katTitlecase()
        } else {
            return s
        }
    }
}