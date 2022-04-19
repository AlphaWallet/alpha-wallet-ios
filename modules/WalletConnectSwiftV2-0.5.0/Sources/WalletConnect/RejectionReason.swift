
import Foundation

/// https://github.com/ChainAgnostic/CAIPs/blob/master/CAIPs/caip-25.md
public enum RejectionReason {
    case disapprovedChains
    case disapprovedMethods
    case disapprovedNotificationTypes
}

internal extension RejectionReason {
    func internalRepresentation() -> SessionType.Reason {
        switch self {
        case .disapprovedChains:
            return SessionType.Reason(code: 5000, message: "User disapproved requested chains")
        case .disapprovedMethods:
            return SessionType.Reason(code: 5001, message: "User disapproved requested json-rpc methods")
        case  .disapprovedNotificationTypes:
            return SessionType.Reason(code: 5002, message: "User disapproved requested notification types")
        }
    }
}
