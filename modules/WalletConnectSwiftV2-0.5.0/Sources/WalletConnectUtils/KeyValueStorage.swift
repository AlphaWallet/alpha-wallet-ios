import Foundation

/// Key Value Storage Protocol
public protocol KeyValueStorage {
    /// Sets the value of the specified default key.
    func set(_ value: Any?, forKey defaultName: String)
    /// Returns the object associated with the specified key.
    func object(forKey defaultName: String) -> Any?
    /// Returns the data object associated with the specified key.
    func data(forKey defaultName: String) -> Data?
    /// Removes the value of the specified default key.
    func removeObject(forKey defaultName: String)
    /// Returns a dictionary that contains a union of all key-value pairs in the domains in the search list.
    func dictionaryRepresentation() -> [String : Any]
}

extension UserDefaults: KeyValueStorage {}

// TODO: Move to test target
public final class RuntimeKeyValueStorage: KeyValueStorage {
    private var storage: [String : Any] = [:]
    private let queue = DispatchQueue(label: "com.walletconnect.sdk.runtimestorage")
    
    public init(storage: [String : Any] = [:]) {
        self.storage = storage
    }

    public func set(_ value: Any?, forKey defaultName: String) {
        queue.sync {
            storage[defaultName] = value
        }
    }

    public func object(forKey defaultName: String) -> Any? {
        queue.sync {
            return storage[defaultName]
        }
    }

    public func data(forKey defaultName: String) -> Data? {
        queue.sync {
            return storage[defaultName] as? Data
        }
    }

    public func removeObject(forKey defaultName: String) {
        queue.sync {
            storage[defaultName] = nil
        }
    }

    public func dictionaryRepresentation() -> [String : Any] {
        queue.sync {
            return storage
        }
    }
}
