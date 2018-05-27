// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

private var liveLocaleSwitcherBundleKey = 0

///Switch in-app locale without restarting app. Need to re-create UI though. There is a mix of use of the words "locale" and "language". When referring to the "language bundle", the word "language" is explicitly used, since that's Apple's terminology.
class LiveLocaleSwitcherBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let languageBundle = objc_getAssociatedObject(self, &liveLocaleSwitcherBundleKey) as? Bundle {
            return languageBundle.localizedString(forKey: key, value: value, table: tableName)
        } else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
    }

    override func url(forResource name: String?, withExtension ext: String?) -> URL? {
        //We want to match "html", but exclude "nib" (for "xib"). Safe to whitelist instead of blacklist
        if ext == "html", let languageBundle = objc_getAssociatedObject(self, &liveLocaleSwitcherBundleKey) as? Bundle {
            return languageBundle.url(forResource: name, withExtension: ext)
        } else {
            return super.url(forResource: name, withExtension: ext)
        }
    }

    //Important to switch to Bundle.self before we do anything, otherwise we wouldn't be able to find the other locales, because we override url(forResource:withExtension:) above
    static func switchLocale(to locale: String?, fallbackToPreferredLocale: Bool = true) {
        object_setClass(Bundle.main, Bundle.self)
        if let locale = locale, let languageBundlePath = Bundle.main.path(forResource: locale, ofType: "lproj") {
            let bundle = Bundle(path: languageBundlePath)
            object_setClass(Bundle.main, LiveLocaleSwitcherBundle.self)
            objc_setAssociatedObject(Bundle.main, &liveLocaleSwitcherBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            //Switch to the system defined locale until app is restarted, at which point app will use the system locale anyway. If our app doesn't support the system-defined locale, we will fallback to "en" (which we do support) instead
            if fallbackToPreferredLocale {
                switchLocale(to: Locale.preferredLanguages[0], fallbackToPreferredLocale: false)
            } else {
                switchLocale(to: "en", fallbackToPreferredLocale: false)
            }
        }
    }
}
