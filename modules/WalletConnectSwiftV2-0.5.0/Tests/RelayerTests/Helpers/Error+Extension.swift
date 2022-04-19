import Foundation
@testable import Relayer

extension NSError {
    
    static func mock(code: Int = -9999) -> NSError {
        NSError(domain: "com.walletconnect.sdk.tests.error", code: code, userInfo: nil)
    }
}

extension Error {
    
    var asNetworkError: NetworkError? {
        return self as? NetworkError
    }
}

extension NetworkError {

    var isWebSocketError: Bool {
        guard case .webSocketNotConnected = self else { return false }
        return true
    }
    
    var isSendMessageError: Bool {
        guard case .sendMessageFailed = self else { return false }
        return true
    }
    
    var isReceiveMessageError: Bool {
        guard case .receiveMessageFailure = self else { return false }
        return true
    }
}

extension String: Error {}
