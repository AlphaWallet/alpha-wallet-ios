
import Foundation

struct PairingProposal: Codable {
    
    let topic: String
    let relay: RelayProtocolOptions
    let proposer: PairingProposer
    let signal: PairingSignal
    let permissions: ProposedPermissions
    let ttl: Int
    
    static func createFromURI(_ uri: WalletConnectURI) -> PairingProposal {
        PairingProposal(
            topic: uri.topic,
            relay: uri.relay,
            proposer: PairingProposer(
                publicKey: uri.publicKey,
                controller: uri.isController),
            signal: PairingSignal(uri: uri.absoluteString),
            permissions: ProposedPermissions.default,
            ttl: PairingSequence.timeToLiveSettled
        )
    }
}

struct PairingSignal: Codable, Equatable {
    let type: String
    let params: Params
    
    init(uri: String) {
        self.type = "uri"
        self.params = Params(uri: uri)
    }
    
    struct Params: Codable, Equatable {
        let uri: String
    }
}

struct PairingProposer: Codable, Equatable {
    let publicKey: String
    let controller: Bool
}

struct ProposedPermissions: Codable, Equatable {
    let jsonrpc: PairingType.JSONRPC
    
    static var `default`: ProposedPermissions {
        ProposedPermissions(jsonrpc: PairingType.JSONRPC(methods: [PairingType.PayloadMethods.sessionPropose.rawValue]))
    }
}

struct PairingState: Codable, Equatable {
    var metadata: AppMetadata?
}

extension PairingType {
    
    struct Permissions: Codable, Equatable {
        let jsonrpc: JSONRPC
        let controller: Controller
    }
    
    struct JSONRPC: Codable, Equatable {
        let methods: [String]
    }
    
    enum PayloadMethods: String, Codable, Equatable {
        case sessionPropose = "wc_sessionPropose"
    }
}
