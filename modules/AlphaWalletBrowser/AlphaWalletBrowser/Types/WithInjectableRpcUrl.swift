// Copyright © 2023 Stormbird PTE. LTD.
import Foundation

public protocol WithInjectableRpcUrl {
    var web3InjectedRpcURL: URL { get }
    var chainID: Int { get}
}
