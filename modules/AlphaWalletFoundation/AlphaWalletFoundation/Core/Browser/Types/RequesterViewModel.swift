//
//  RequesterViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.06.2022.
//

import Foundation

public protocol RequesterViewModel {
    var requester: Requester { get }
    var viewModels: [Any] { get }
}

extension RequesterViewModel {
    public var iconUrl: URL? { return requester.iconUrl }
}
