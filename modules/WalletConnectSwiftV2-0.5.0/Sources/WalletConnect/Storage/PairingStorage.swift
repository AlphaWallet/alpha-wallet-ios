protocol PairingSequenceStorage: AnyObject {
    var onSequenceExpiration: ((_ topic: String, _ pubKey: String) -> Void)? { get set }
    func hasSequence(forTopic topic: String) -> Bool
    func setSequence(_ sequence: PairingSequence)
    func getSequence(forTopic topic: String) throws -> PairingSequence?
    func getAll() -> [PairingSequence]
    func delete(topic: String)
}

final class PairingStorage: PairingSequenceStorage {
    
    var onSequenceExpiration: ((String, String) -> Void)? {
        get { storage.onSequenceExpiration }
        set { storage.onSequenceExpiration = newValue }
    }
    
    private let storage: SequenceStore<PairingSequence>
    
    init(storage: SequenceStore<PairingSequence>) {
        self.storage = storage
    }
    
    func hasSequence(forTopic topic: String) -> Bool {
        storage.hasSequence(forTopic: topic)
    }
    
    func setSequence(_ sequence: PairingSequence) {
        storage.setSequence(sequence)
    }
    
    func getSequence(forTopic topic: String) throws -> PairingSequence? {
        try storage.getSequence(forTopic: topic)
    }
    
    func getAll() -> [PairingSequence] {
        storage.getAll()
    }
    
    func delete(topic: String) {
        storage.delete(topic: topic)
    }
}
