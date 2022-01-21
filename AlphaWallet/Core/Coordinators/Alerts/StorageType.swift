//
//  StorageType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit

protocol StorageType {
    @discardableResult func dataExists(forKey key: String) -> Bool
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

    func load<T: Codable>(forKey key: String) -> T? {
        guard let data = data(forKey: key) else {
            return nil
        }

        guard let result = try? JSONDecoder().decode(T.self, from: data) else {
            return nil
        }

        return result
    }
}

struct FileStorage: StorageType {
    var fileExtension: String = "data"
    private let serialQueue: DispatchQueue = DispatchQueue(label: "org.alphawallet.swift.file")
    var directoryUrl: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }()

    func dataExists(forKey key: String) -> Bool {
        let url = fileURL(with: key, fileExtension: fileExtension)
        return FileManager.default.fileExists(atPath: url.path)
    }

    func data(forKey key: String) -> Data? {
        let url = fileURL(with: key, fileExtension: fileExtension)
        var data: Data?
        
        dispatchPrecondition(condition: .notOnQueue(serialQueue))
        serialQueue.sync {
            data = try? Data(contentsOf: url)
        }

        return data
    }

    func setData(_ data: Data, forKey key: String) -> Bool {
        var url = fileURL(with: key, fileExtension: fileExtension)
        var result: Bool = false
        
        dispatchPrecondition(condition: .notOnQueue(serialQueue))
        serialQueue.sync {
            do {
                try data.write(to: url, options: .atomicWrite)
                try url.addSkipBackupAttributeToItemAtURL()

                result = true
            } catch {
                result = false
            }
        }

        return result
    }

    func deleteEntry(forKey key: String) -> Bool {
        let url = fileURL(with: key, fileExtension: fileExtension)
        var result: Bool = false

        dispatchPrecondition(condition: .notOnQueue(serialQueue))
        serialQueue.sync {
            do {
                try FileManager.default.removeItem(at: url)
                result = true
            } catch {
                result = false
            }
        }

        return result
    }

    private func fileURL(with key: String, fileExtension: String = "data") -> URL {
        return directoryUrl.appendingPathComponent("\(key).\(fileExtension)", isDirectory: false)
    }
}

extension URL {
    mutating func addSkipBackupAttributeToItemAtURL() throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true

        try self.setResourceValues(resourceValues)
    }
}
