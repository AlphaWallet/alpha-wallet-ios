// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class AssetDefinitionDiskBackingStore: AssetDefinitionBackingStore {
    private static let officialDirectoryName = "assetDefinitions"

    private let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    private let assetDefinitionsDirectoryName: String
    lazy var directory = documentsDirectory.appendingPathComponent(assetDefinitionsDirectoryName)
    private let isOfficial: Bool
    weak var delegate: AssetDefinitionBackingStoreDelegate?
    private var directoryWatcher: DirectoryContentsWatcherProtocol?

    init(directoryName: String = officialDirectoryName) {
        self.assetDefinitionsDirectoryName = directoryName
        self.isOfficial = assetDefinitionsDirectoryName == AssetDefinitionDiskBackingStore.officialDirectoryName

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit {
        try? directoryWatcher?.stop()
    }

    private func localURLOfXML(for contract: String) -> URL {
        return directory.appendingPathComponent(filename(fromContract: contract))
    }

    private func filename(fromContract contract: String) -> String {
        let name = standardizedName(ofContract: contract)
        return "\(name).xml"
    }

    static func contract(fromPath path: URL) -> String? {
        guard path.lastPathComponent.hasPrefix("0x") else { return nil }
        guard path.pathExtension == "xml" else { return nil }
        return path.deletingPathExtension().lastPathComponent
    }

    static func isValidAssetDefinitionFilename(forPath path: URL) -> Bool {
        return contract(fromPath: path) != nil
    }

    subscript(contract: String) -> String? {
        get {
            let path = localURLOfXML(for: contract)
            return try? String(contentsOf: path)
        }
        set(xml) {
            guard let xml = xml else {
                return
            }
            //TODO validate XML signature first
            let path = localURLOfXML(for: contract)
            try? xml.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    func isOfficial(contract: String) -> Bool {
        return isOfficial
    }

    func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: String) -> Date? {
        let path = localURLOfXML(for: contract)
        guard let lastModified = try? path.resourceValues(forKeys: [.contentModificationDateKey]) else {
            return nil
        }
        return lastModified.contentModificationDate
    }

    func forEachContractWithXML(_ body: (String) -> Void) {
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            let contracts = files.compactMap { AssetDefinitionDiskBackingStore.contract(fromPath: $0) }
            for each in contracts {
                body(each)
            }
        }
    }

    func watchDirectoryContents(changeHandler: @escaping (String) -> Void) {
        guard directoryWatcher == nil else { return }
        directoryWatcher = DirectoryContentsWatcher.Local(path: directory.path)
        do {
            try directoryWatcher?.start { [weak self] results in
                guard let strongSelf = self else { return }
                switch results {
                case .noChanges:
                    break
                case .updated(let filenames):
                    for each in filenames {
                        if let url = URL(string: each), let contract = AssetDefinitionDiskBackingStore.contract(fromPath: url) {
                            changeHandler(contract)
                        }
                    }
                }
            }
        } catch {
        }
    }
}
