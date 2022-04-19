@testable import WalletConnect
import Foundation

final class SessionSequenceStorageMock: SessionSequenceStorage {
    
    var onSequenceExpiration: ((String, String) -> Void)?
    
    private(set) var sessions: [String: SessionSequence] = [:]
    
    func hasSequence(forTopic topic: String) -> Bool {
        sessions[topic] != nil
    }
    
    func setSequence(_ sequence: SessionSequence) {
        sessions[sequence.topic] = sequence
    }
    
    func getSequence(forTopic topic: String) -> SessionSequence? {
        return sessions[topic]
    }
    
    func getAll() -> [SessionSequence] {
        Array(sessions.values)
    }
    
    func delete(topic: String) {
        sessions[topic] = nil
    }
}

extension SessionSequenceStorageMock {
    
    func hasPendingProposedPairing(on topic: String) -> Bool {
        guard case .proposed = sessions[topic]?.pending?.status else { return false }
        return true
    }
}
