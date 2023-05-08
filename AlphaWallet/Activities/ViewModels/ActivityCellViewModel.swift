// Copyright © 2020 Stormbird PTE. LTD.

import AlphaWalletFoundation
import BigInt
import Foundation

struct ActivityCellViewModel {
    private var server: RPCServer {
        activity.server
    }

    let activity: Activity

    var contentsBackgroundColor: UIColor {
        Configuration.Color.Semantic.tableViewCellBackground
    }

    var contentsCornerRadius: CGFloat {
        return DataEntry.Metric.CornerRadius.box
    }

    var backgroundColor: UIColor {
        return Configuration.Color.Semantic.tableViewCellBackground
    }
}
