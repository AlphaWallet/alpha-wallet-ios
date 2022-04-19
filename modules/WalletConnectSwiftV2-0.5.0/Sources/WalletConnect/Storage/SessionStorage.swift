protocol SessionSequenceStorage: AnyObject {
    var onSequenceExpiration: ((_ topic: String, _ pubKey: String) -> Void)? { get set }
    func hasSequence(forTopic topic: String) -> Bool
    func setSequence(_ sequence: SessionSequence)
    func getSequence(forTopic topic: String) -> SessionSequence?
    func getAll() -> [SessionSequence]
    func delete(topic: String)
}

final class SessionStorage: SessionSequenceStorage {
    
    var onSequenceExpiration: ((String, String) -> Void)? {
        get { storage.onSequenceExpiration }
        set { storage.onSequenceExpiration = newValue }
    }
    
    private let storage: SequenceStore<SessionSequence>
    
    init(storage: SequenceStore<SessionSequence>) {
        self.storage = storage
    }
    
    func hasSequence(forTopic topic: String) -> Bool {
        storage.hasSequence(forTopic: topic)
    }
    
    func setSequence(_ sequence: SessionSequence) {
        storage.setSequence(sequence)
    }
    
    func getSequence(forTopic topic: String) -> SessionSequence? {
        return try? storage.getSequence(forTopic: topic)
    }
    
    func getAll() -> [SessionSequence] {
        storage.getAll()
    }
    
    func delete(topic: String) {
        storage.delete(topic: topic)
    }
}
