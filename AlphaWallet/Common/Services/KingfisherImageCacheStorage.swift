//
//  KingfisherImageCacheStorage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.02.2023.
//

import Foundation
import Kingfisher

final class KingfisherImageCacheStorage: ContentCacheStorage {
    private let diskStorage = ImageCache(name: "aw-cache-store").diskStorage

    func value(for key: String) throws -> Data? {
        try diskStorage.value(forKey: key)
    }

    func set(data: Data, for key: String) throws {
        try diskStorage.store(value: data, forKey: key)
    }
}
