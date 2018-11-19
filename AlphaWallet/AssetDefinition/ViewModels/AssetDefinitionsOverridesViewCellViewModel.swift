// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct AssetDefinitionsOverridesViewCellViewModel {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    var text: String {
        return AssetDefinitionDiskBackingStore.contract(fromPath: url) ?? "N/A"
    }

    let backgroundColor = Colors.appBackground
    let bubbleBackgroundColor = Colors.appWhite
    let bubbleRadius = CGFloat(20)

    let textColor = Colors.appText
    let textFont = Fonts.light(size: 18)!
    let textLineBreakMode = NSLineBreakMode.byTruncatingMiddle
}
