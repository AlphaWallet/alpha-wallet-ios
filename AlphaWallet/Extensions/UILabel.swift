// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

extension UILabel {
    
    func setLineHeight(lineHeight: CGFloat) {
        let text = self.text
        if let text = text {
            let attributeString = NSMutableAttributedString(string: text)
            let style = NSMutableParagraphStyle()
            
            style.minimumLineHeight = lineHeight
            attributeString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.count))
            self.attributedText = attributeString
        }
    }
}
