// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

///Used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
class RoundedBackground: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Colors.appWhite
        //No longer rounded. We are keeping this class and its instance around in case the visual design changes
//        cornerRadius = 20
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func createConstraintsWithContainer(view: UIView) -> [NSLayoutConstraint] {
        let marginToHideBottomRoundedCorners = CGFloat(30)
        return view.anchorsConstraint(to: self, edgeInsets: .init(top: 0, left: 0, bottom: marginToHideBottomRoundedCorners, right: 0))
    }
}
