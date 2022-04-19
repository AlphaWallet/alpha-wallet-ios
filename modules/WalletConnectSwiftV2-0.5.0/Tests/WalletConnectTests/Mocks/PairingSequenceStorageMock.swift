@testable import WalletConnect

final class PairingSequenceStorageMock: PairingSequenceStorage {
    
    var onSequenceExpiration: ((String, String) -> Void)?
    
    private(set) var pairings: [String: PairingSequence] = [:]
    
    func hasSequence(forTopic topic: String) -> Bool {
        pairings[topic] != nil
    }
    
    func setSequence(_ sequence: PairingSequence) {
        pairings[sequence.topic] = sequence
    }
    
    func getSequence(forTopic topic: String) throws -> PairingSequence? {
        pairings[topic]
    }
    
    func getAll() -> [PairingSequence] {
        Array(pairings.values)
    }
    
    func delete(topic: String) {
        pairings[topic] = nil
    }
}

extension PairingSequenceStorageMock {
    
    func hasPendingProposedPairing(on topic: String) -> Bool {
        guard case .proposed = pairings[topic]?.pending?.status else { return false }
        return true
    }
    
    func hasPendingRespondedPairing(on topic: String) -> Bool {
        guard case .responded = pairings[topic]?.pending?.status else { return false }
        return true
    }
    
    func hasPreSettledPairing(on topic: String) -> Bool {
        pairings[topic]?.settled?.status == .preSettled
    }
    
    func hasAcknowledgedPairing(on topic: String) -> Bool {
        pairings[topic]?.settled?.status == .acknowledged
    }
}
