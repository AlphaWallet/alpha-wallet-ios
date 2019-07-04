// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

struct SeedPhraseCellViewModel {
   let word: String

   var backgroundColor: UIColor {
      return UIColor(red: 234, green: 234, blue: 234)
   }

   var textColor: UIColor {
      return UIColor(red: 87, green: 87, blue: 87)
   }

   var font: UIFont {
       if ScreenChecker().isNarrowScreen {
           return Fonts.regular(size: 15)!
       } else {
           return Fonts.regular(size: 18)!
       }
   }
}
