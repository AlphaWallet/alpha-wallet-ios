// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import PromiseKit

class OpenSeaNonFungibleTokenViewCellViewModel {
    private static var imageGenerator = ConvertSVGToPNG(cachingDirectoryName: "collectiblesContractImageCache")
    private let token: TokenObject
    var imageUrl: URL?
    var image: Promise<UIImage>?
    var title: String {
        return token.name
    }

    init(config: Config, token: TokenObject) {
        self.token = token
        //We use the contract's image and fallback to the first token ID's image if the former is not available
        if let tokenHolder = TokenAdaptor(config: config, token: token).getTokenHolders().first {
            var url = tokenHolder.values["contractImageUrl"] as? String ?? ""
            if url.isEmpty {
                url = tokenHolder.values["imageUrl"] as? String ?? ""
            }
            self.imageUrl = URL(string: url)
            if imageUrl != nil {
                let tokenId = tokenHolder.values["tokenId"] as? String
                self.image = OpenSeaNonFungibleTokenViewCellViewModel.imageGenerator.withDownloadedImage(fromURL: imageUrl, forTokenId: tokenId, withPrefix: tokenHolder.contractAddress)
            } else {
                self.imageUrl = nil
                self.image = nil
            }
        } else {
            self.imageUrl = nil
            self.image = nil
        }
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleColor: UIColor {
        return Colors.appBackground
    }

    var titleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }
}
