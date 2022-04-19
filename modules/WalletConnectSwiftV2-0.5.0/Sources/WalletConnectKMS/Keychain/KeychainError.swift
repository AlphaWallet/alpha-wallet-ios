import Foundation

// TODO: Integrate with WalletConnectError
struct KeychainError: Error {
    
    let status: OSStatus
    
    init(_ status: OSStatus) {
        self.status = status
    }
}

extension KeychainError: CustomStringConvertible {
    
    var description: String {
        status.message
    }
}

extension OSStatus {
    /// A human readable message for the status.
    var message: String {
        return (SecCopyErrorMessageString(self, nil) as String?) ?? String(self)
    }
}
