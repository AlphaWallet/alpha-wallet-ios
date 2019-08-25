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

    init(config: Config, token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore) {
        self.token = token
        //We use the contract's image and fallback to the first token ID's image if the former is not available
        if let tokenHolder = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore).getTokenHolders(forWallet: account).first {
            var url = tokenHolder.values["contractImageUrl"]?.stringValue ?? ""
            if url.isEmpty {
                url = tokenHolder.values["imageUrl"]?.stringValue ?? ""
            }
            self.imageUrl = URL(string: url)
            if imageUrl != nil {
                let tokenId = tokenHolder.values["tokenId"]?.stringValue
                self.image = OpenSeaNonFungibleTokenViewCellViewModel.imageGenerator.withDownloadedImage(fromURL: imageUrl, forTokenId: tokenId, withPrefix: tokenHolder.contractAddress.eip55String)
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

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var titleColor: UIColor {
        return Colors.appBackground
    }

    var titleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }
}
