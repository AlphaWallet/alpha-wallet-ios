//
//  KingfisherImageFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.09.2022.
//

import AlphaWalletFoundation
import Foundation
import Kingfisher

class KingfisherImageFetcher: ImageFetcher {

    func retrieveImage(with url: URL) async throws -> UIImage {
        let resource = ImageResource(downloadURL: url, cacheKey: url.absoluteString)

        return try await withUnsafeThrowingContinuation { continuation in
            KingfisherManager.shared.retrieveImage(with: resource) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response.image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
