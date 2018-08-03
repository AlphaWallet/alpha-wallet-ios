// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Macaw

struct BaseTicketTableViewCellViewModel {
    let ticketHolder: TokenHolder

    init(
            ticketHolder: TokenHolder
    ) {
        self.ticketHolder = ticketHolder
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var status: String {
        return ""
    }

    var cellHeight: CGFloat {
        let detailsHeight = CGFloat(34)
        if ticketHolder.areDetailsVisible {
            return 120 + detailsHeight
        } else {
            return 120
        }
        }

    var checkboxImage: UIImage {
        if ticketHolder.isSelected {
            return R.image.ticket_bundle_checked()!
        } else {
            return R.image.ticket_bundle_unchecked()!
        }
    }

    var areDetailsVisible: Bool {
        return ticketHolder.areDetailsVisible
    }

    var assetImageNode: Node? {
        guard let imageIdentifier = ticketHolder.imageIdentifier else { return nil }
        guard let imageType = ticketHolder.imageType else { return nil }
        let imageStore = AssetImageStore(contract: ticketHolder.contractAddress, imageType: imageType)
        guard let path = imageStore[imageIdentifier] else { return nil }
        guard let text = try? String(contentsOfFile: path, encoding: String.Encoding.utf8) else { return nil }
        return try? SVGParser.parse(text: text)
    }
}
