//
//  BlockiesImage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import AlphaWalletCore
import UIKit

public enum BlockiesImage {
    case image(image: UIImage, isEnsAvatar: Bool)
    case url(url: WebImageURL, isEnsAvatar: Bool)

    public var isEnsAvatar: Bool {
        switch self {
        case .image(_, let isEnsAvatar):
            return isEnsAvatar
        case .url(_, let isEnsAvatar):
            return isEnsAvatar
        }
    }
}

extension BlockiesImage: Hashable {}
