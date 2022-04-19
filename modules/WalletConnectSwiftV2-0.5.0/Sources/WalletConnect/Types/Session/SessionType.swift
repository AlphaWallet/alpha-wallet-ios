import Foundation
import WalletConnectUtils

// Internal namespace for session payloads.
internal enum SessionType {
    
    typealias ProposeParams = SessionProposal
    
    struct ApproveParams: Codable, Equatable {
        let relay: RelayProtocolOptions
        let responder: SessionParticipant
        let expiry: Int
        let state: SessionState
    }
    
    struct RejectParams: Codable, Equatable {
        let reason: Reason
    }
    
    struct UpdateParams: Codable, Equatable {
        let state: SessionState
        
        init(accounts: Set<String>) {
            self.state = SessionState(accounts: accounts)
        }
    }
    
    struct UpgradeParams: Codable, Equatable {
        let permissions: SessionPermissions
    }
    
    struct DeleteParams: Codable, Equatable {
        let reason: Reason
        init(reason: SessionType.Reason) {
            self.reason = reason
        }
    }
    
    struct Reason: Codable, Equatable {
        let code: Int
        let message: String
        
        init(code: Int, message: String) {
            self.code = code
            self.message = message
        }
    }
    
    struct PayloadParams: Codable, Equatable {
        let request: Request
        let chainId: String?
        
        struct Request: Codable, Equatable {
            let method: String
            let params: AnyCodable
        }
    }
    
    struct NotificationParams: Codable, Equatable {
        let type: String
        let data: AnyCodable
        
        init(type: String, data: AnyCodable) {
            self.type = type
            self.data = data
        }
    }
    
    struct PingParams: Codable, Equatable {} // Is an empty struct really needed?
}

// A better solution could fit in here
internal extension Reason {
    func toInternal() -> SessionType.Reason {
        SessionType.Reason(code: self.code, message: self.message)
    }
}

extension SessionType.Reason {
    func toPublic() -> Reason {
        Reason(code: self.code, message: self.message)
    }
}
