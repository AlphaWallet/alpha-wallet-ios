// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class AssetDefinitionDiskBackingStore: AssetDefinitionBackingStore {
    init() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    lazy private var directory = documentsDirectory.appendingPathComponent("assetDefinitions")

    private func localURLOfXML(for contract: String) -> URL {
        return directory.appendingPathComponent(filename(fromContract: contract))
    }

    private func filename(fromContract contract: String) -> String {
        let name = standardizedName(ofContract: contract)
        return "\(name).xml"
    }

    subscript(contract: String) -> String? {
        get {
            let path = localURLOfXML(for: contract)
            return try? String(contentsOf: path)
        }
        set(xml) {
            guard let xml = xml else { return }
            //TODO validate XML signature first
            let path = localURLOfXML(for: contract)
            try? xml.write(to: path, atomically: true, encoding: .utf8)
        }
    }

    func lastModifiedDataOfCachedAssetDefinitionFile(forContract contract: String) -> Date? {
        let path = localURLOfXML(for: contract)
        guard let lastModified = try? path.resourceValues(forKeys: [.contentModificationDateKey]) else { return nil }
        return lastModified.contentModificationDate as? Date
    }

    func forEachContractWithXML(_ body: (String) -> Void) {
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for each in files {
                guard each.pathExtension == "xml" else { continue }
                let contract = each.deletingPathExtension().lastPathComponent
                body(contract)
            }
        }
    }
}
