//
//  RemoteTokenEntriesProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 05.09.2022.
//

import AlphaWalletCore
import Combine
import CombineExt
import Foundation

//TODO: Future impl for remote TokenEntries provider
public final class RemoteTokenEntriesProvider: TokenEntriesProvider {
    public func tokenEntries() -> AnyPublisher<[TokenEntry], PromiseError> {
        return .just([])
            .share()
            .eraseToAnyPublisher()
    }
}
