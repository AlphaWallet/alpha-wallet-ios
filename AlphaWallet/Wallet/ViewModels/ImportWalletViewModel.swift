// Copyright SIX DAY LLC. All rights reserved.

import UIKit

struct ImportWalletViewModel {
    //Must be computed because localization can be overridden by user dynamically
    static var segmentedControlTitles: [String] { ImportWalletTab.orderedTabs.map { $0.title } }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var title: String {
        return R.string.localizable.importNavigationTitle(preferredLanguages: Languages.preferred())
    }

    var mnemonicLabel: String {
        return R.string.localizable.mnemonic(preferredLanguages: Languages.preferred()).uppercased()
    }

    var keystoreJSONLabel: String {
        return R.string.localizable.keystoreJSON(preferredLanguages: Languages.preferred()).uppercased()
    }

    var passwordLabel: String {
        return R.string.localizable.password(preferredLanguages: Languages.preferred()).uppercased()
    }

    var privateKeyLabel: String {
        return R.string.localizable.privateKey(preferredLanguages: Languages.preferred()).uppercased()
    }

    var watchAddressLabel: String {
        return R.string.localizable.ethereumAddress(preferredLanguages: Languages.preferred()).uppercased()
    }

    var importKeystoreJsonButtonFont: UIFont {
        return Fonts.regular(size: ScreenChecker().isNarrowScreen ? 16 : 20)
    }

    var importSeedAttributedText: NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        return .init(string: R.string.localizable.importWalletImportSeedPhraseDescription(preferredLanguages: Languages.preferred()), attributes: [
            .paragraphStyle: style,
            .font: Fonts.light(size: ScreenChecker().isNarrowScreen ? 14 : 16),
            .foregroundColor: UIColor(red: 116, green: 116, blue: 116)
        ])
    }

    func convertSegmentedControlSelectionToFilter(_ selection: SegmentedControl.Selection) -> ImportWalletTab? {
        switch selection {
        case .selected(let index):
            return ImportWalletTab.filter(fromIndex: index)
        case .unselected:
            return nil
        }
    }
}

extension ImportWalletTab {
    static var orderedTabs: [ImportWalletTab] {
        return [
            .mnemonic,
            .keystore,
            .privateKey,
            .watch,
        ]
    }

    static func filter(fromIndex index: UInt) -> ImportWalletTab? {
        return ImportWalletTab.orderedTabs.first { $0.selectionIndex == index }
    }

    var title: String {
        switch self {
        case .mnemonic:
            return R.string.localizable.mnemonicShorter(preferredLanguages: Languages.preferred())
        case .keystore:
            return ImportSelectionType.keystore.title
        case .privateKey:
            return ImportSelectionType.privateKey.title
        case .watch:
            return ImportSelectionType.watch.title
        }
    }

    var selectionIndex: UInt {
        //This is safe only because index can't possibly be negative
        return UInt(ImportWalletTab.orderedTabs.firstIndex(of: self) ?? 0)
    }
}
