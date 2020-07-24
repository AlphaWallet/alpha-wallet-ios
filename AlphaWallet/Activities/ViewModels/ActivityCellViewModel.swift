// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

struct ActivityCellViewModel {
    private var server: RPCServer {
        activity.server
    }

    let activity: Activity

    var contentsBackgroundColor: UIColor {
        .white
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }
}
