import Foundation
@testable import WalletConnectKMS

final class KeychainStorageMock: KeychainStorageProtocol {
    
    var storage: [String: Data] = [:]
    
    private(set) var didCallAdd = false
    private(set) var didCallRead = false
    private(set) var didCallDelete = false
    
    func add<T>(_ item: T, forKey key: String) throws where T : GenericPasswordConvertible {
        didCallAdd = true
        storage[key] = item.rawRepresentation
    }
    
    func read<T>(key: String) throws -> T where T : GenericPasswordConvertible {
        didCallRead = true
        if let data = storage[key] {
            return try T(rawRepresentation: data)
        }
        throw KeychainError(errSecItemNotFound)
    }
    
    func delete(key: String) throws {
        didCallDelete = true
        storage[key] = nil
    }
}
