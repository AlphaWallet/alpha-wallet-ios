import Foundation

protocol KeychainStorageProtocol {
    func add<T: GenericPasswordConvertible>(_ item: T, forKey key: String) throws
    func read<T: GenericPasswordConvertible>(key: String) throws -> T
    func delete(key: String) throws
}

final class KeychainStorage: KeychainStorageProtocol {
    
    private let service: String
    
    private let secItem: KeychainServiceProtocol
    
    init(keychainService: KeychainServiceProtocol = KeychainServiceWrapper(), serviceIdentifier: String) {
        self.secItem = keychainService
        service = serviceIdentifier
    }
    
    func add<T>(_ item: T, forKey key: String) throws where T : GenericPasswordConvertible {
        try add(data: item.rawRepresentation, forKey: key)
    }
    
    func add(data: Data, forKey key: String) throws {
        var query = buildBaseServiceQuery(for: key)
        query[kSecValueData] = data
        
        let status = secItem.add(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError(status)
        }
    }
    
    func read<T>(key: String) throws -> T where T : GenericPasswordConvertible {
        guard let data = try readData(key: key) else {
            throw KeychainError(errSecItemNotFound)
        }
        return try T(rawRepresentation: data)
    }
    
    func readData(key: String) throws -> Data? {
        var query = buildBaseServiceQuery(for: key)
        query[kSecReturnData] = true
        
        var item: CFTypeRef?
        let status = secItem.copyMatching(query as CFDictionary, &item)
        
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status)
        }
    }
    
    func update<T>(_ item: T, forKey key: String) throws where T : GenericPasswordConvertible {
        try update(data: item.rawRepresentation, forKey: key)
    }
    
    func update(data: Data, forKey key: String) throws {
        let query = buildBaseServiceQuery(for: key)
        let attributes = [kSecValueData: data]
        
        let status = secItem.update(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            throw KeychainError(status)
        }
    }
    
    func delete(key: String) throws {
        let query = buildBaseServiceQuery(for: key)
        
        let status = secItem.delete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status)
        }
    }
    
    func deleteAll() throws {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ] as [String: Any]
        let status = secItem.delete(query as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError(status)
        }
    }
    
    private func buildBaseServiceQuery(for key: String) -> [CFString: Any] {
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrIsInvisible: true,
            kSecUseDataProtectionKeychain: true,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
    }
}
