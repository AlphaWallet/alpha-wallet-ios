import Foundation
import WalletConnectUtils

protocol Expirable {
    var expiryDate: Date { get }
}

protocol ExpirableSequence: Codable, Expirable {
    var topic: String { get }
    var publicKey: String { get }
}

final class SequenceStore<T> where T: ExpirableSequence {

    var onSequenceExpiration: ((_ topic: String, _ pubKey: String) -> Void)?
    
    private let storage: KeyValueStorage
    private let dateInitializer: () -> Date
    private let identifier: String

    init(storage: KeyValueStorage, identifier: String, dateInitializer: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.dateInitializer = dateInitializer
        self.identifier = identifier
    }
    
    func hasSequence(forTopic topic: String) -> Bool {
        (try? getSequence(forTopic: topic)) != nil
    }
    
    //  This force-unwrap is safe because Expirable Sequances are JSON Encodable
    func setSequence(_ sequence: T) {
        let encoded = try! JSONEncoder().encode(sequence)
        storage.set(encoded, forKey: getKey(for: sequence.topic))
    }

    func getSequence(forTopic topic: String) throws -> T? {
        guard let data = storage.object(forKey: getKey(for: topic)) as? Data else { return nil }
        let sequence = try JSONDecoder().decode(T.self, from: data)
        return verifyExpiry(on: sequence)
    }

    func getAll() -> [T] {
        return storage.dictionaryRepresentation().compactMap {
            guard $0.key.hasPrefix(identifier) else {return nil}
            if let data = $0.value as? Data, let sequence = try? JSONDecoder().decode(T.self, from: data) {
                return verifyExpiry(on: sequence)
            }
            return nil
        }
    }

    func delete(topic: String) {
        storage.removeObject(forKey: getKey(for: topic))
    }
    
    private func verifyExpiry(on sequence: T) -> T? {
        let now = dateInitializer()
        if now >= sequence.expiryDate {
            storage.removeObject(forKey: getKey(for: sequence.topic))
            onSequenceExpiration?(sequence.topic, sequence.publicKey)
            return nil
        }
        return sequence
    }
    
    private func getKey(for topic: String) -> String {
        return "\(identifier).\(topic)"
    }
}
