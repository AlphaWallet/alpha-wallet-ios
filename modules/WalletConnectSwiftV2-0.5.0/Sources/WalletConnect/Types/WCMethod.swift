enum WCMethod {
    case wcPairingApprove(PairingType.ApprovalParams)
    case wcPairingUpdate(PairingType.UpdateParams)
    case wcPairingPayload(PairingType.PayloadParams)
    case wcPairingPing
    case wcSessionApprove(SessionType.ApproveParams)
    case wcSessionReject(SessionType.RejectParams)
    case wcSessionUpdate(SessionType.UpdateParams)
    case wcSessionUpgrade(SessionType.UpgradeParams)
    case wcSessionDelete(SessionType.DeleteParams)
    case wcSessionPayload(SessionType.PayloadParams)
    case wcSessionPing
    case wcSessionNotification(SessionType.NotificationParams)
    
    func asRequest() -> WCRequest {
        switch self {
        case .wcPairingApprove(let approveParams):
            return WCRequest(method: .pairingApprove, params: .pairingApprove(approveParams))
        case .wcPairingUpdate(let updateParams):
            return WCRequest(method: .pairingUpdate, params: .pairingUpdate(updateParams))
        case .wcPairingPayload(let payloadParams):
            return WCRequest(method: .pairingPayload, params: .pairingPayload(payloadParams))
        case .wcPairingPing:
            return WCRequest(method: .pairingPing, params: .pairingPing(PairingType.PingParams()))
        case .wcSessionApprove(let approveParams):
            return WCRequest(method: .sessionApprove, params: .sessionApprove(approveParams))
        case .wcSessionReject(let rejectParams):
            return WCRequest(method: .sessionReject, params: .sessionReject(rejectParams))
        case .wcSessionUpdate(let updateParams):
            return WCRequest(method: .sessionUpdate, params: .sessionUpdate(updateParams))
        case .wcSessionUpgrade(let upgradeParams):
            return WCRequest(method: .sessionUpgrade, params: .sessionUpgrade(upgradeParams))
        case .wcSessionDelete(let deleteParams):
            return WCRequest(method: .sessionDelete, params: .sessionDelete(deleteParams))
        case .wcSessionPayload(let payloadParams):
            return WCRequest(method: .sessionPayload, params: .sessionPayload(payloadParams))
        case .wcSessionPing:
            return WCRequest(method: .sessionPing, params: .sessionPing(SessionType.PingParams()))
        case .wcSessionNotification(let notificationParams):
            return WCRequest(method: .sessionNotification, params: .sessionNotification(notificationParams))
        }
    }
}
