// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

struct PromptViewModel {
    let title: String
    let description: String
    let buttonTitle: String

    var backgroundColor: UIColor {
        Colors.clear
    }

    var footerBackgroundColor: UIColor {
        Configuration.Color.Semantic.defaultViewBackground
    }
}
