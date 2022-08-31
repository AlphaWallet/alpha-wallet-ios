// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

//TODO make TokenCardTableViewCellWithoutCheckbox, etc cell classes be generic (with TokenRowView as the type parameter). Unfortunately: https://bugs.swift.org/browse/SR-6977 is only fixed in Swift 4.2, aka Xcode 10.
protocol TokenRowView: AnyObject {
    func configure(tokenHolder: TokenHolder)
    //TODO getting rid of these will be good
    var background: UIView { get }
    var stateLabel: UILabel { get }
}
