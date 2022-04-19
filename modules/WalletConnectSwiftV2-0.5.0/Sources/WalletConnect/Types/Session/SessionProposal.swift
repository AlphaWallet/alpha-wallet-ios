
import Foundation

struct SessionState: Codable, Equatable {
    var accounts: Set<String>
}

struct SessionProposal: Codable, Equatable {
    let topic: String
    let relay: RelayProtocolOptions
    let proposer: SessionType.Proposer
    let signal: SessionType.Signal
    let permissions: SessionPermissions
    let ttl: Int
}

extension SessionType {
    
    struct Proposer: Codable, Equatable {
        let publicKey: String
        let controller: Bool
        let metadata: AppMetadata
    }
    
    struct Signal: Codable, Equatable {
        struct Params: Codable, Equatable {
            let topic: String
        }
        let method: String
        let params: Params
    }
}
