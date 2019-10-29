// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct DappsAutoCompletionCellViewModel {
    let dapp: Dapp
    let keyword: String

    var backgroundColor: UIColor {
        return UIColor(red: 244, green: 244, blue: 244)
    }

    var name: NSAttributedString {
        let text = NSMutableAttributedString(string: dapp.name)
        text.setAttributes([NSAttributedString.Key.foregroundColor: nameColor as Any], range: .init(location: 0, length: dapp.name.count))
        if let range = dapp.name.lowercased().range(of: keyword.lowercased()) {
            let location = dapp.name.distance(from: dapp.name.startIndex, to: range.lowerBound)
            let length = keyword.count
            text.setAttributes([NSAttributedString.Key.foregroundColor: Colors.appBackground], range: .init(location: location, length: length))
        }
        return text
    }

    var description: String {
        return dapp.description
    }

    var nameFont: UIFont {
        return Fonts.regular(size: 16)!
    }

    var descriptionFont: UIFont {
        return Fonts.light(size: 12)!
    }

    private var nameColor: UIColor? {
        return UIColor(red: 55, green: 55, blue: 55)
    }

    var descriptionColor: UIColor? {
        return UIColor(red: 77, green: 77, blue: 77)
    }
}
