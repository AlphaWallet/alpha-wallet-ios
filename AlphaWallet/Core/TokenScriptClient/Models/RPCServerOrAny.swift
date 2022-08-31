// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

enum RPCServerOrAny: Hashable {
    case any
    case server(RPCServer)

    func matches(server target: RPCServer) -> Bool {
        switch self {
        case .any:
            return true
        case .server(let server):
            return server == target
        }
    }
}
