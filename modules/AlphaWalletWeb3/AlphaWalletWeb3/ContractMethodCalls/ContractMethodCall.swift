// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress

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

public extension ContractMethodCall {
    var parameters: [AnyObject] { return [] }
    var shouldDelayIfCached: Bool { return false }

    public var description: String {
        return "contract: \(contract), name: \(name), parameters: \(parameters)"
    }
}

