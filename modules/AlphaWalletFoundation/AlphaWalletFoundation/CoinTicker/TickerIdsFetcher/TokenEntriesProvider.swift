//
//  TokenEntriesProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.09.2022.
//

import AlphaWalletCore
import Combine
import Foundation

/// Provides tokens groups
public protocol TokenEntriesProvider {
    func tokenEntries() -> AnyPublisher<[TokenEntry], PromiseError>
}
