//
//  ContractMethodCall.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 09.01.2023.
//

import Foundation

public protocol ContractMethodCall: CustomStringConvertible {
    associatedtype Response

    var contract: AlphaWallet.Address { get }
    var abi: String { get }
    var name: String { get }
    var parameters: [AnyObject] { get }
    /// Special flag for token script
    var shouldDelayIfCached: Bool { get }

    func response(from dictionary: [String: Any]) throws -> Response
}

extension ContractMethodCall {
    var parameters: [AnyObject] { return [] }
    var shouldDelayIfCached: Bool { return false }

    public var description: String {
        return "contract: \(contract), name: \(name), parameters: \(parameters)"
    }
}
