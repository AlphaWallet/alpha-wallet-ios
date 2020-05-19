// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct AccountOptionViewModel {
    
    let title: String
    let description: String?
    
    var titleColor: UIColor {
        .black
    }
    
    var descriptionColor: UIColor {
        return R.color.dove()!
    }
    
    var titleFont: UIFont {
        return Fonts.regular(size: 17)!
    }
    
    var descriptionFont: UIFont {
        return Fonts.regular(size: 13)!
    }
}
