// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class AssetDefinitionDiskBackingStore: AssetDefinitionBackingStore {
    private static let officialDirectoryName = "assetDefinitions"
    static let fileExtension = "tsml"

    private let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    private let assetDefinitionsDirectoryName: String
    lazy var directory = documentsDirectory.appendingPathComponent(assetDefinitionsDirectoryName)
    private let isOfficial: Bool
    weak var delegate: AssetDefinitionBackingStoreDelegate?
    private var directoryWatcher: DirectoryContentsWatcherProtocol?
    private var tokenScriptFileIndices = TokenScriptFileIndices()

    init(directoryName: String = officialDirectoryName) {
        self.assetDefinitionsDirectoryName = directoryName
        self.isOfficial = assetDefinitionsDirectoryName == AssetDefinitionDiskBackingStore.officialDirectoryName

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadTokenScriptFileIndices()
    }

    deinit {
        try? directoryWatcher?.stop()
    }

    private func loadTokenScriptFileIndices() {
        tokenScriptFileIndices = .init()
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }

        for eachUrl in urls {
            guard eachUrl.pathExtension == AssetDefinitionDiskBackingStore.fileExtension || eachUrl.pathExtension == "xml" else { continue }
            guard let contents = try? String(contentsOf: eachUrl) else { continue }
            //TODO don't use regex. When we finally use XMLHandler to extract entities, we have to be careful not to create AssetDefinitionStore instances within XMLHandler otherwise infinite recursion by calling this func again
            let contracts = XMLHandler.getContracts(forTokenScript: contents)
            var entities = XMLHandler.getEntities(forTokenScript: contents)
            for (eachContract, _) in contracts {
                tokenScriptFileIndices.contractsToFileNames[eachContract] = eachUrl.lastPathComponent
                tokenScriptFileIndices.contractsToEntities[eachContract] = entities
            }
        }
    }

    private func localURLOfXML(for contract: String) -> URL {
        if let filename = tokenScriptFileIndices.contractsToFileNames[standardizedName(ofContract: contract)] {
            return directory.appendingPathComponent(filename)
        } else {
            return directory.appendingPathComponent(filename(fromContract: contract))
        }
    }

    private func filename(fromContract contract: String) -> String {
        let name = standardizedName(ofContract: contract)
        return "\(name).\(AssetDefinitionDiskBackingStore.fileExtension)"
    }

    subscript(contract: String) -> String? {
        get {
            let path = localURLOfXML(for: contract)
            guard var xmlContents = try? String(contentsOf: path) else { return nil }
            guard let entities = tokenScriptFileIndices.contractsToEntities[standardizedName(ofContract: contract)] else { return xmlContents }
            for each in entities {
                let url = directory.appendingPathComponent(each.fileName)
                guard let contents = try? String(contentsOf: url) else { continue }
                xmlContents = (xmlContents as NSString).replacingOccurrences(of: "&\(each.name);", with: contents)
            }
            return xmlContents
        }
        set(xml) {
            guard let xml = xml else {
                return
            }
            //TODO validate XML signature first
            let path = localURLOfXML(for: contract)
            try? xml.write(to: path, atomically: true, encoding: .utf8)
            handleTokenScriptFileChanged(withFilename: path.lastPathComponent, changeHandler: { _ in })
        }
    }

    func isOfficial(contract: String) -> Bool {
        return isOfficial
    }

    func isCanonicalized(contract: String) -> Bool {
        //TODO improve that that we can standard contract names better. EIP55? Is it too slow because of the "Address" classes we use to generate it?
        if let filename = tokenScriptFileIndices.contractsToFileNames[contract.lowercased()] {
            return filename.hasSuffix(".\(AssetDefinitionDiskBackingStore.fileExtension)")
        } else  {
            //We return true because then it'll be treated as needing a higher security level rather than a non-canonicalized (debug version)
            return true
        }
    }

    func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: String) -> Date? {
        let path = localURLOfXML(for: contract)
        guard let lastModified = try? path.resourceValues(forKeys: [.contentModificationDateKey]) else {
            return nil
        }
        return lastModified.contentModificationDate
    }

    func forEachContractWithXML(_ body: (String) -> Void) {
        for (contract, _) in tokenScriptFileIndices.contractsToFileNames {
            body(contract)
        }
    }

    func watchDirectoryContents(changeHandler: @escaping (String) -> Void) {
        guard directoryWatcher == nil else { return }
        directoryWatcher = DirectoryContentsWatcher.Local(path: directory.path)
        try? directoryWatcher?.start { [weak self] results in
            guard let strongSelf = self else { return }
            switch results {
            case .noChanges:
                break
            case .updated(let filenames):
                for each in filenames {
                    strongSelf.handleTokenScriptFileChanged(withFilename: each, changeHandler: changeHandler)
                }
            }
        }
    }

    private func handleTokenScriptFileChanged(withFilename filename: String, changeHandler: @escaping (String) -> Void) {
        let url = directory.appendingPathComponent(filename)
        var contractsAffected: [String]
        if url.pathExtension == AssetDefinitionDiskBackingStore.fileExtension || url.pathExtension == "xml" {
            let contractsPreviouslyForThisXmlFile = tokenScriptFileIndices.contractsToFileNames.filter { eachContract, eachFileName in
                return eachFileName == filename
            }.map { $0.key }
            for eachContract in contractsPreviouslyForThisXmlFile {
                tokenScriptFileIndices.contractsToFileNames.removeValue(forKey: eachContract)
            }

            let contracts: [String]
            if let contents = try? String(contentsOf: url) {
                contracts = XMLHandler.getContracts(forTokenScript: contents).map { $0.0 }
                var entities = XMLHandler.getEntities(forTokenScript: contents)
                for eachContract in contracts {
                    tokenScriptFileIndices.contractsToFileNames[eachContract] = url.lastPathComponent
                    tokenScriptFileIndices.contractsToEntities[eachContract] = entities
                }
            } else {
                contracts = []
            }

            contractsAffected = contracts + contractsPreviouslyForThisXmlFile
        } else {
            contractsAffected = [String]()
            for (contract, entities) in tokenScriptFileIndices.contractsToEntities {
                if entities.contains(where: { $0.fileName == filename }) {
                    contractsAffected.append(contract)
                }
            }
        }
        for each in Array(Set(contractsAffected)) {
            changeHandler(each)
        }
    }
}
