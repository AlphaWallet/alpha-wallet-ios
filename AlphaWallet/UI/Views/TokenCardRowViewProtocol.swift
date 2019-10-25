// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol TokenCardRowViewProtocol {
    var checkboxImageView: UIImageView { get }
    var stateLabel: UILabel { get set }
    var tokenView: TokenView { get set }
    var showCheckbox: Bool { get set }
    var areDetailsVisible: Bool { get set }

    func configure(tokenHolder: TokenHolder, tokenView: TokenView, areDetailsVisible: Bool, width: CGFloat, assetDefinitionStore: AssetDefinitionStore)
}
