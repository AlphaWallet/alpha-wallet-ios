// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct AssetDefinitionsOverridesViewCellViewModel {
    private let url: URL
    private let fileExtension: String

    init(url: URL, fileExtension: String) {
        self.url = url
        self.fileExtension = fileExtension
    }

    var text: String {
        return url.lastPathComponent
    }

    let backgroundColor = Colors.appBackground

    let textColor = Colors.appText
    let textFont = Fonts.regular(size: 18)
    let textLineBreakMode = NSLineBreakMode.byTruncatingMiddle
}
