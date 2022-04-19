import Foundation

protocol KeychainServiceProtocol {
    func add(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func copyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    func update(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus
    func delete(_ query: CFDictionary) -> OSStatus
}

final class KeychainServiceWrapper: KeychainServiceProtocol {
    
    func add(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        return SecItemAdd(attributes, result)
    }
    
    func copyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        return SecItemCopyMatching(query, result)
    }
    
    func update(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus {
        return SecItemUpdate(query, attributesToUpdate)
    }
    
    func delete(_ query: CFDictionary) -> OSStatus {
        return SecItemDelete(query)
    }
}
