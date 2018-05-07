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

    override func url(forResource name: String?, withExtension ext: String?) -> URL? {
        if let languageBundle = objc_getAssociatedObject(self, &liveLanguageSwitcherBundleKey) as? Bundle {
            return languageBundle.url(forResource: name, withExtension: ext)
        } else {
            return super.url(forResource: name, withExtension: ext)
        }
    }

    //Important to switch to Bundle.self before we do anything, otherwise we wouldn't be able to find the other languages, because we override url(forResource:withExtension:) above
    static func switchLanguage(to language: String?) {
        object_setClass(Bundle.main, Bundle.self)
        if let language = language, let languageBundlePath = Bundle.main.path(forResource: language, ofType: "lproj") {
            let bundle = Bundle(path: languageBundlePath)
            object_setClass(Bundle.main, LiveLanguageSwitcherBundle.self)
            objc_setAssociatedObject(Bundle.main, &liveLanguageSwitcherBundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            //Switch to the system defined language until app is restarted, at which point app will use the system language anyway
            switchLanguage(to: Locale.preferredLanguages[0])
        }
    }
}
