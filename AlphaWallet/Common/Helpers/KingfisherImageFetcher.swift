//
//  KingfisherImageFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.09.2022.
//

import Foundation
import Kingfisher
import AlphaWalletFoundation
import PromiseKit

class KingfisherImageFetcher: ImageFetcher {

    func retrieveImage(with url: URL) -> Promise<UIImage> {
        let resource = ImageResource(downloadURL: url, cacheKey: url.absoluteString)

        return Promise { seal in
            KingfisherManager.shared.retrieveImage(with: resource) { result in
                switch result {
                case .success(let response):
                    seal.fulfill(response.image)
                case .failure(let error):
                    seal.reject(error)
                }
            }
        }
    }
}
