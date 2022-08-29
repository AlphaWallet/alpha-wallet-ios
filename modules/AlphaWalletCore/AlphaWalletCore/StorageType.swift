//
//  StorageType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.09.2021.
//

import UIKit

public protocol StorageType {
    @discardableResult func dataExists(forKey key: String) -> Bool
    @discardableResult func data(forKey: String) -> Data?
    @discardableResult func setData(_ data: Data, forKey: String) -> Bool
    @discardableResult func deleteEntry(forKey: String) -> Bool
}

public extension StorageType {
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

public struct FileStorage: StorageType {
    public var fileExtension: String = "data"
    private let serialQueue: DispatchQueue = DispatchQueue(label: "org.alphawallet.swift.file")
    public var directoryUrl: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }()

    public init() {

    }

    public func dataExists(forKey key: String) -> Bool {
        let url = fileURL(with: key, fileExtension: fileExtension)
        return FileManager.default.fileExists(atPath: url.path)
    }

    public func data(forKey key: String) -> Data? {
        let url = fileURL(with: key, fileExtension: fileExtension)
        var data: Data?

        dispatchPrecondition(condition: .notOnQueue(serialQueue))
        serialQueue.sync {
            data = try? Data(contentsOf: url)
        }

        return data
    }

    public func setData(_ data: Data, forKey key: String) -> Bool {
        var url = fileURL(with: key, fileExtension: fileExtension)
        var result: Bool = false

        dispatchPrecondition(condition: .notOnQueue(serialQueue))
        serialQueue.sync {
            do {
                try data.write(to: url, options: .atomicWrite)
                try url.addSkipBackupAttributeToItemAtURL()
                try url.addProtectionKeyNone()

                result = true
            } catch {
                result = false
            }
        }

        return result
    }

    public func deleteEntry(forKey key: String) -> Bool {
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

    public func fileURL(with key: String, fileExtension: String = "data") -> URL {
        return directoryUrl.appendingPathComponent("\(key).\(fileExtension)", isDirectory: false)
    }
}

public class InMemoryStorage: StorageType {
    public var fileExtension: String = "data"
    private let serialQueue: DispatchQueue = DispatchQueue(label: "org.alphawallet.swift.file")
    private var data: [URL: Data] = [:]
    public var directoryUrl: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }()

    public init() {

    }

    public func dataExists(forKey key: String) -> Bool {
        let url = fileURL(with: key, fileExtension: fileExtension)
        return data[url] != nil
    }

    public func data(forKey key: String) -> Data? {
        let url = fileURL(with: key, fileExtension: fileExtension)
        var data: Data?

        dispatchPrecondition(condition: .notOnQueue(serialQueue))
        serialQueue.sync {
            data = self.data[url]
        }

        return data
    }

    public func setData(_ data: Data, forKey key: String) -> Bool {
        var url = fileURL(with: key, fileExtension: fileExtension)
        var result: Bool = false

        dispatchPrecondition(condition: .notOnQueue(serialQueue))
        serialQueue.sync {
            self.data[url] = data
        }

        return result
    }

    public func deleteEntry(forKey key: String) -> Bool {
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

public extension InMemoryStorage {
    convenience init(fileExtension: String = "data", directoryUrl: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.init()
        self.fileExtension = fileExtension
        self.directoryUrl = directoryUrl
    }
}

public extension FileStorage {
    init(fileExtension: String = "data", directoryUrl: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.fileExtension = fileExtension
        self.directoryUrl = directoryUrl
    }
}

public extension URL {
    mutating func addSkipBackupAttributeToItemAtURL() throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true

        try setResourceValues(resourceValues)
    }

    mutating func addProtectionKeyNone() throws {
        guard FileManager.default.fileExists(atPath: relativePath) else { return }

        let attributes = try FileManager.default.attributesOfItem(atPath: relativePath)
        let protectionType = attributes[.protectionKey] as? FileProtectionType
        if protectionType != .some(FileProtectionType.none) {
            try FileManager.default.setAttributes([
                FileAttributeKey.protectionKey: FileProtectionType.none
            ], ofItemAtPath: relativePath)
        }
    }
}

public extension FileStorage {
    static func forTestSuite(folder: String = "testSuiteForAddressStorage", fileExtension: String = "json") throws -> FileStorage {
        try removeAddressFolderForTests(name: folder)

        let url = try addressStorageUrlInCacheFolder(folder)
        return FileStorage(fileExtension: fileExtension, directoryUrl: url)
    }

    private static func addressStorageUrlInCacheFolder(_ folder: String) throws -> URL {
        let fileManager = FileManager.default

        func createSubDirectoryIfNotExists(name: String) throws -> URL {
            let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]

            let directory = documentsURL.appendingPathComponent(name)
            guard !fileManager.fileExists(atPath: directory.absoluteString) else { return directory }
            try fileManager.createDirectory(atPath: directory.path, withIntermediateDirectories: true, attributes: nil)

            return directory
        }

        return try createSubDirectoryIfNotExists(name: folder)
    }

    private static func removeAddressFolderForTests(name: String) throws {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = documentsURL.appendingPathComponent(name)

        try? fileManager.removeItem(atPath: directory.absoluteString)
    }
}
