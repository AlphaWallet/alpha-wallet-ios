
import Foundation
@testable import WalletConnect
extension WCRequest {
    
    var isPairingApprove: Bool {
        if case .pairingApprove = self.params { return true }
        return false
    }
}

extension PairingType.ApprovalParams {
    
    static func stub() -> PairingType.ApprovalParams {
        let options = RelayProtocolOptions(protocol: "", params: nil)
        let participant = PairingParticipant(publicKey: "")
        return PairingType.ApprovalParams(relay: options, responder: participant, expiry: 0, state: nil)
    }
}
