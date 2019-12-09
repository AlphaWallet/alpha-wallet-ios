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
    private var cachedVersionOfXDaiBridgeTokenScript: String?

    private var indicesFileUrl: URL {
        return directory.appendingPathComponent(TokenScript.indicesFileName)
    }

    var badTokenScriptFileNames: [TokenScriptFileIndices.FileName] {
        if isOfficial {
            //We exclude .xml in the directory for files downloaded from the repo. Because this are based on pre 2019/04 schemas. We should just delete them
            return tokenScriptFileIndices.badTokenScriptFileNames.filter { !$0.hasSuffix(".xml") }
        } else {
            return tokenScriptFileIndices.badTokenScriptFileNames
        }
    }

    var conflictingTokenScriptFileNames: [TokenScriptFileIndices.FileName] {
        return tokenScriptFileIndices.conflictingTokenScriptFileNames
    }

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
        let previousTokenScriptFileIndices = TokenScriptFileIndices.load(fromUrl: indicesFileUrl) ?? .init()
        tokenScriptFileIndices = .init()
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }

        for eachUrl in urls {
            guard eachUrl.pathExtension == AssetDefinitionDiskBackingStore.fileExtension || eachUrl.pathExtension == "xml" else { continue }
            guard let contents = try? String(contentsOf: eachUrl) else { continue }
            let fileName = eachUrl.lastPathComponent
            //TODO don't use regex. When we finally use XMLHandler to extract entities, we have to be careful not to create AssetDefinitionStore instances within XMLHandler otherwise infinite recursion by calling this func again
            if let contracts = XMLHandler.getHoldingContracts(forTokenScript: contents) {
                let entities = XMLHandler.getEntities(forTokenScript: contents)
                for (eachContract, _) in contracts {
                    tokenScriptFileIndices.contractsToFileNames[eachContract, default: []] += [fileName]
                }
                tokenScriptFileIndices.contractsToEntities[fileName] = entities
                tokenScriptFileIndices.trackHash(forFile: fileName, contents: contents)
            } else {
                var isOldTokenScriptVersion = false
                for (contract, fileNames) in previousTokenScriptFileIndices.contractsToOldTokenScriptFileNames {
                    if fileNames.contains(fileName) {
                        let newHash = tokenScriptFileIndices.hash(contents: contents)
                        if newHash == previousTokenScriptFileIndices.fileHashes[fileName] {
                            tokenScriptFileIndices.contractsToOldTokenScriptFileNames[contract, default: []] += [fileName]
                            tokenScriptFileIndices.trackHash(forFile: fileName, contents: contents)
                            isOldTokenScriptVersion = true
                        }
                    }
                }
                if !isOldTokenScriptVersion {
                    for (contract, fileNames) in previousTokenScriptFileIndices.contractsToFileNames {
                        if fileNames.contains(fileName) {
                            let newHash = tokenScriptFileIndices.hash(contents: contents)
                            if newHash == previousTokenScriptFileIndices.fileHashes[fileName] {
                                tokenScriptFileIndices.contractsToOldTokenScriptFileNames[contract, default: []] += [fileName]
                                tokenScriptFileIndices.trackHash(forFile: fileName, contents: contents)
                                isOldTokenScriptVersion = true
                            }
                        }
                    }
                }
                if !isOldTokenScriptVersion {
                    tokenScriptFileIndices.badTokenScriptFileNames += [fileName]
                    delegate?.badTokenScriptFilesChanged(in: self)
                }
            }
        }
        tokenScriptFileIndices.copySignatureVerificationTypes(previousTokenScriptFileIndices.signatureVerificationTypes)
        writeIndicesToDisk()
    }

    private func writeIndicesToDisk() {
        tokenScriptFileIndices.write(toUrl: indicesFileUrl)
    }

    private func localURLOfXML(for contract: AlphaWallet.Address) -> URL {
        assert(isOfficial)
        return directory.appendingPathComponent(filename(fromContract: contract))
    }

    ///Only return XML contents if there is exactly 1 file that matches the contract
    private func xml(forContract contract: AlphaWallet.Address) -> String? {
        guard let fileName = tokenScriptFileIndices.nonConflictingFileName(forContract: contract) else { return nil }
        let path = directory.appendingPathComponent(fileName)
        return try? String(contentsOf: path)
    }

    private func filename(fromContract contract: AlphaWallet.Address) -> String {
        return "\(contract.eip55String).\(AssetDefinitionDiskBackingStore.fileExtension)"
    }

    subscript(contract: AlphaWallet.Address) -> String? {
        get {
            //TODO this is the bundled version of the XDai bridge. Should remove it when the repo server can server action-only TokenScripts
            if isOfficial && contract.sameContract(as: Constants.nativeCryptoAddressInDatabase) {
                if cachedVersionOfXDaiBridgeTokenScript == nil {
                    cachedVersionOfXDaiBridgeTokenScript = Bundle.main.url(forResource: "XDAI-bridge", withExtension: ".tsml").flatMap { try? String(contentsOf: $0) }
                }
                return cachedVersionOfXDaiBridgeTokenScript
            }

            guard var xmlContents = xml(forContract: contract) else { return nil }
            guard let fileName = tokenScriptFileIndices.nonConflictingFileName(forContract: contract) else { return xmlContents }
            guard let entities = tokenScriptFileIndices.contractsToEntities[fileName] else { return xmlContents }
            for each in entities {
                //Guard against XML entity injection
                guard !each.fileName.contains("/") else { continue }
                let url = directory.appendingPathComponent(each.fileName)
                guard let contents = try? String(contentsOf: url) else { continue }
                xmlContents = (xmlContents as NSString).replacingOccurrences(of: "&\(each.name);", with: contents)
            }
            return xmlContents
        }
        set(xml) {
            guard let xml = xml else { return }
            let path = localURLOfXML(for: contract)
            try? xml.write(to: path, atomically: true, encoding: .utf8)
            handleTokenScriptFileChanged(withFilename: path.lastPathComponent, changeHandler: { _ in })
        }
    }

    func isOfficial(contract: AlphaWallet.Address) -> Bool {
        return isOfficial
    }

    ///We don't bother to check if there's a conflict inside this function because if there's a conflict, the files should be ignored anyway
    func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        if let filename = tokenScriptFileIndices.contractsToFileNames[contract]?.first {
            return filename.hasSuffix(".\(AssetDefinitionDiskBackingStore.fileExtension)")
        } else {
            //We return true because then it'll be treated as needing a higher security level rather than a non-canonicalized (debug version)
            return true
        }
    }

    func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        return tokenScriptFileIndices.hasConflictingFile(forContract: contract)
    }

    func hasOutdatedTokenScript(forContract contract: AlphaWallet.Address) -> Bool {
        return !tokenScriptFileIndices.contractsToOldTokenScriptFileNames[contract].isEmpty
    }

    func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return tokenScriptFileIndices.signatureVerificationTypes[tokenScriptFileIndices.hash(contents: xmlString)]
    }

    func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        tokenScriptFileIndices.signatureVerificationTypes[tokenScriptFileIndices.hash(contents: xmlString)] = verificationType
        tokenScriptFileIndices.write(toUrl: indicesFileUrl)
    }

    //When we remove a contract from our database, we must remove the TokenScript file (from the standard repo) that is named after it because this file wouldn't be pulled from the server anymore. If the TokenScript file applies to more than 1 contract, having the outdated file around will mean 2 copies of the same file — with 1 outdated, 1 up-to-date, causing TokenScript client to see a conflict
    func deleteFileDownloadedFromOfficialRepoFor(contract: AlphaWallet.Address) {
        guard isOfficial else { return }
        let filename = self.filename(fromContract: contract)
        let url = directory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        tokenScriptFileIndices.removeHash(forFile: filename)

        var contractsToFileNames = tokenScriptFileIndices.contractsToFileNames
        for (eachContract, eachFilenames) in tokenScriptFileIndices.contractsToFileNames {
            if eachFilenames.contains(filename) {
                var updatedFilenames = eachFilenames
                updatedFilenames.removeAll { $0 == filename }
                contractsToFileNames[eachContract] = updatedFilenames
            }
        }
        tokenScriptFileIndices.contractsToFileNames = contractsToFileNames
        tokenScriptFileIndices.contractsToEntities[filename] = nil
        tokenScriptFileIndices.removeBadTokenScriptFileName(filename)
        tokenScriptFileIndices.removeOldTokenScriptFileName(filename)
        writeIndicesToDisk()
    }

    //Must only return the last modified date for a file if it's for the current schema version otherwise, a file using the old schema might have a more recent timestamp (because it was recently downloaded) than a newer version on the server (which was not yet made available by the time the user downloaded the version with the old schema)
    func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        assert(isOfficial)
        let path = localURLOfXML(for: contract)
        guard let lastModified = try? path.resourceValues(forKeys: [.contentModificationDateKey]) else { return nil }
        guard XMLHandler.isTokenScriptSupportedSchemaVersion(path) else { return nil }
        return lastModified.contentModificationDate
    }

    func forEachContractWithXML(_ body: (AlphaWallet.Address) -> Void) {
        for (contract, _) in tokenScriptFileIndices.contractsToFileNames {
            body(contract)
        }
    }

    func watchDirectoryContents(changeHandler: @escaping (AlphaWallet.Address) -> Void) {
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

    private func handleTokenScriptFileChanged(withFilename fileName: String, changeHandler: @escaping (AlphaWallet.Address) -> Void) {
        let url = directory.appendingPathComponent(fileName)
        var contractsAffected: [AlphaWallet.Address]
        if url.pathExtension == AssetDefinitionDiskBackingStore.fileExtension || url.pathExtension == "xml" {
            let contractsPreviouslyForThisXmlFile = tokenScriptFileIndices.contractsToFileNames.filter { eachContract, fileNames in
                return fileNames.contains(fileName)
            }.map { $0.key }
            for eachContract in contractsPreviouslyForThisXmlFile {
                if var fileNames = tokenScriptFileIndices.contractsToFileNames[eachContract], fileNames.count > 1 {
                    fileNames.removeAll { $0 == fileName }
                    tokenScriptFileIndices.contractsToFileNames[eachContract] = fileNames
                } else {
                    tokenScriptFileIndices.contractsToFileNames.removeValue(forKey: eachContract)
                }
            }
            tokenScriptFileIndices.contractsToEntities.removeValue(forKey: fileName)
            tokenScriptFileIndices.removeHash(forFile: fileName)

            let contracts: [AlphaWallet.Address]
            if let contents = try? String(contentsOf: url) {
                if let holdingContracts = XMLHandler.getHoldingContracts(forTokenScript: contents)?.map({ $0.0 }) {
                    contracts = holdingContracts
                    let entities = XMLHandler.getEntities(forTokenScript: contents)
                    for eachContract in contracts {
                        tokenScriptFileIndices.contractsToFileNames[eachContract, default: []] += [fileName]
                    }
                    tokenScriptFileIndices.contractsToEntities[fileName] = entities
                    tokenScriptFileIndices.trackHash(forFile: fileName, contents: contents)
                    tokenScriptFileIndices.removeBadTokenScriptFileName(fileName)
                    tokenScriptFileIndices.removeOldTokenScriptFileName(fileName)
                } else {
                    contracts = []
                    tokenScriptFileIndices.badTokenScriptFileNames += [fileName]
                }
            } else {
                contracts = []
                tokenScriptFileIndices.removeHash(forFile: fileName)
                tokenScriptFileIndices.removeBadTokenScriptFileName(fileName)
                tokenScriptFileIndices.removeOldTokenScriptFileName(fileName)
            }

            contractsAffected = contracts + contractsPreviouslyForThisXmlFile
        } else {
            contractsAffected = [AlphaWallet.Address]()
            for (xmlFileName, entities) in tokenScriptFileIndices.contractsToEntities {
                if entities.contains(where: { $0.fileName == fileName }) {
                    let contracts = tokenScriptFileIndices.contracts(inFileName: xmlFileName)
                    contractsAffected.append(contentsOf: contracts)
                }
            }
        }
        purgeCacheFor(contracts: contractsAffected, changeHandler: changeHandler)
        writeIndicesToDisk()
        delegate?.badTokenScriptFilesChanged(in: self)
    }

    private func purgeCacheFor(contracts: [AlphaWallet.Address], changeHandler: @escaping (AlphaWallet.Address) -> Void) {
        //Import to clear the signature cache (which includes conflicts) because a file which was in conflict with another earlier might no longer be
        //TODO clear the cache more intelligently rather than purge it entirely. It might be hard or impossible to know which other contracts are affected
        tokenScriptFileIndices.signatureVerificationTypes = .init()
        for each in Array(Set(contracts)) {
            XMLHandler.invalidate(forContract: each)
            changeHandler(each)
        }
    }
}
