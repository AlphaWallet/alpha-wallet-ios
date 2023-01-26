// Copyright © 2021 Stormbird PTE. LTD.

import UIKit

struct PromptViewModel {
    let title: String
    let description: String
    let buttonTitle: String

    var backgroundColor: UIColor {
        Configuration.Color.Semantic.backgroundClear
    }

    var footerBackgroundColor: UIColor {
        Configuration.Color.Semantic.defaultViewBackground
    }
}
