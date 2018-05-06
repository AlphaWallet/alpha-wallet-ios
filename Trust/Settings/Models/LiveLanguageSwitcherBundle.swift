// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

private var liveLanguageSwitcherBundleKey = 0

///Switch in-app language without restarting app. Need to re-create UI though
class LiveLanguageSwitcherBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let languageBundle = objc_getAssociatedObject(self, &liveLanguageSwitcherBundleKey) as? Bundle {
            return languageBundle.localizedString(forKey: key, value: value, table: tableName)
        } else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
    }

    static func switchLanguage(to language: String?) {
        if let language = language, let languageBundlePath = Bundle.main.path(forResource: language, ofType: "lproj") {
            let bundle = Bundle(path: languageBundlePath)
            object_setClass(Bundle.main, LiveLanguageSwitcherBundle.self)
            objc_setAssociatedObject(Bundle.main, &liveLanguageSwitcherBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            object_setClass(Bundle.main, Bundle.self)
        }
    }
}
