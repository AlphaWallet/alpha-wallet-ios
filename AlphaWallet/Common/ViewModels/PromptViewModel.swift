// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

struct PromptViewModel {
    let title: String
    let description: String
    let buttonTitle: String

    var backgroundColor: UIColor {
        UIColor.clear
    }

    var footerBackgroundColor: UIColor {
        Colors.appWhite
    }
}
