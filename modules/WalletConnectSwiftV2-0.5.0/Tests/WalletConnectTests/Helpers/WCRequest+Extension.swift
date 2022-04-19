@testable import WalletConnect

extension WCRequest {
    
    var pairingApproveParams: PairingType.ApprovalParams? {
        guard case .pairingApprove(let approveParams) = self.params else { return nil }
        return approveParams
    }
    
    var sessionProposal: SessionProposal? {
        guard case .pairingPayload(let payload) = self.params else { return nil }
        return payload.request.params
    }
    
    var approveParams: SessionType.ApproveParams? {
        guard case .sessionApprove(let approveParams) = self.params else { return nil }
        return approveParams
    }
}
