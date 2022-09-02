//
//  ConfigureImageStorage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.06.2022.
//

import Kingfisher

public final class ConfigureImageStorage: Initializer {
    public init() {}
    public func perform() {
        // Configure Kingfisher's Cache
        let cache = ImageCache.default

        // Constrain Memory Cache to 50 MB
        cache.memoryStorage.config.totalCostLimit = 1024 * 1024 * 50

        // Constrain Disk Cache to 100 MB
        cache.diskStorage.config.sizeLimit = 1024 * 1024 * 300
    }
}
