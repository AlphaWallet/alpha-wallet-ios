
import Foundation

// Internal namespace for pairing payloads.
internal enum PairingType {
    
    struct ApprovalParams: Codable, Equatable {
        let relay: RelayProtocolOptions
        let responder: PairingParticipant
        let expiry: Int
        let state: PairingState?
    }
    
    struct RejectParams: Codable, Equatable {
        let reason: String
    }
    
    struct DeleteParams: Codable, Equatable {
        let reason: Reason
    }
    
    struct Reason: Codable, Equatable {
        let code: Int
        let message: String
    }
    
    struct UpdateParams: Codable, Equatable {
        let state: PairingState
    }
    
    struct UpgradeParams: Codable, Equatable {
        let permissions: Permissions
    }
    
    struct PayloadParams: Codable, Equatable {
        let request: Request
        
        struct Request: Codable, Equatable {
            let method: PairingType.PayloadMethods
            let params: SessionType.ProposeParams
        }
    }
    
    struct PingParams: Codable, Equatable {} // Is an empty struct really needed?
}
