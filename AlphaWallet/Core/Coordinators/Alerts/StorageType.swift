//
//  StorageType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit

protocol StorageType {
    @discardableResult func data(forKey: String) -> Data?
    @discardableResult func setData(_ data: Data, forKey: String) -> Bool
    @discardableResult func deleteEntry(forKey: String) -> Bool
}

extension StorageType {
    func load<T: Codable>(forKey key: String, defaultValue: T) -> T {
        guard let data = data(forKey: key) else {
            return defaultValue
        }

        guard let result = try? JSONDecoder().decode(T.self, from: data) else {
            //NOTE: in case if decoding error appears, remove existed file
            deleteEntry(forKey: key)

            return defaultValue
        }

        return result
    }
}

struct FileStorage: StorageType {

    private var documentsDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    func data(forKey key: String) -> Data? {
        let url = fileURL(with: key)
        let data = try? Data(contentsOf: url)
        return data
    }

    func setData(_ data: Data, forKey key: String) -> Bool {
        var url = fileURL(with: key)
        do {
            try data.write(to: url, options: .atomicWrite)
            try url.addSkipBackupAttributeToItemAtURL()

            return true
        } catch {
            return false
        }
    }

    func deleteEntry(forKey key: String) -> Bool {
        let url = fileURL(with: key)
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    private func fileURL(with key: String, fileExtension: String = "data") -> URL {
        return documentsDirectory.appendingPathComponent("\(key).\(fileExtension)", isDirectory: false)
    }
}

extension URL {
    mutating func addSkipBackupAttributeToItemAtURL() throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true

        try self.setResourceValues(resourceValues)
    }
}

