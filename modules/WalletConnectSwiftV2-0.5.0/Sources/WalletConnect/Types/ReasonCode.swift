enum ReasonCode {
    
    enum Context: String {
        case pairing = "pairing"
        case session = "session"
    }
    
    // 0 (Generic)
    case generic(message: String)
    
    // 1000 (Internal)
    case missingOrInvalid(String)
    case invalidUpdateRequest(context: Context)
    case invalidUpgradeRequest(context: Context)
    case noContextWithTopic(context: Context, topic: String)
    
    // 3000 (Unauthorized)
    case unauthorizedTargetChain(String)
    case unauthorizedRPCMethod(String)
    case unauthorizedNotificationType(String)
    case unauthorizedUpdateRequest(context: Context)
    case unauthorizedUpgradeRequest(context: Context)
    case unauthorizedMatchingController(isController: Bool)
    
    var code: Int {
        switch self {
        case .generic: return 0
        case .missingOrInvalid: return 1000
        case .invalidUpdateRequest: return 1003
        case .invalidUpgradeRequest: return 1004
        case .noContextWithTopic: return 1301
        case .unauthorizedTargetChain: return 3000
        case .unauthorizedRPCMethod: return 3001
        case .unauthorizedNotificationType: return 3002
        case .unauthorizedUpdateRequest: return 3003
        case .unauthorizedUpgradeRequest: return 3004
        case .unauthorizedMatchingController: return 3005
        }
    }
    
    var message: String {
        switch self {
        case .generic(let message):
            return message
        case .missingOrInvalid(let name):
            return "Missing or invalid \(name)"
        case .invalidUpdateRequest(let context):
            return "Invalid \(context) update request"
        case .invalidUpgradeRequest(let context):
            return "Invalid \(context) upgrade request"
        case .noContextWithTopic(let context, let topic):
            return "No matching \(context) with topic: \(topic)"
        case .unauthorizedTargetChain(let chainId):
            return "Unauthorized target chain id requested: \(chainId)"
        case .unauthorizedRPCMethod(let method):
            return "Unauthorized JSON-RPC method requested: \(method)"
        case .unauthorizedNotificationType(let type):
            return "Unauthorized notification type requested: \(type)"
        case .unauthorizedUpdateRequest(let context):
            return "Unauthorized \(context) update request"
        case .unauthorizedUpgradeRequest(let context):
            return "Unauthorized \(context) upgrade request"
        case .unauthorizedMatchingController(let isController):
            return "Unauthorized: peer is also \(isController ? "" : "non-")controller"
        }
    }
}
