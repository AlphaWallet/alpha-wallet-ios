// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import AlphaWalletAttestation
import AlphaWalletCore
import AlphaWalletLogger
import CryptoKit

public class AssetDefinitionDiskBackingStore {
    public static let officialDirectoryName = "assetDefinitions"

    private let documentsDirectory = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
    private let assetDefinitionsDirectoryName: String
    lazy var directory = documentsDirectory.appendingPathComponent(assetDefinitionsDirectoryName)
    private let isOfficial: Bool
    public weak var delegate: AssetDefinitionBackingStoreDelegate?
    public weak var resolver: TokenScriptResolver?
    private var directoryWatcher: DirectoryContentsWatcherProtocol?
    //Most if not all changes should be performed on copy in a functional "computeXXX()" and then returned and assigned back to this property (and persisted). Easier for maintenance
    private var tokenScriptFileIndices = TokenScriptFileIndices()
    private var cachedVersionOfXDaiBridgeTokenScript: String?

    private var indicesFileUrl: URL {
        return directory.appendingPathComponent(TokenScript.indicesFileName)
    }

    public var badTokenScriptFileNames: [Filename] {
        if isOfficial {
            //We exclude .xml in the directory for files downloaded from the repo. Because this are based on pre 2019/04 schemas. We should just delete them
            return tokenScriptFileIndices.badTokenScriptFileNames.filter { !$0.value.hasSuffix(".xml") }
        } else {
            return tokenScriptFileIndices.badTokenScriptFileNames
        }
    }

    public var conflictingTokenScriptFileNames: (official: [Filename], overrides: [Filename], all: [Filename]) {
        if isOfficial {
            return (official: tokenScriptFileIndices.conflictingTokenScriptFileNames, overrides: [], all: tokenScriptFileIndices.conflictingTokenScriptFileNames)
        } else {
            return (official: [], overrides: tokenScriptFileIndices.conflictingTokenScriptFileNames, all: tokenScriptFileIndices.conflictingTokenScriptFileNames)
        }
    }

    public init(directoryName: String = officialDirectoryName, resetFolders: Bool) {
        self.assetDefinitionsDirectoryName = directoryName
        self.isOfficial = assetDefinitionsDirectoryName == AssetDefinitionDiskBackingStore.officialDirectoryName
        if resetFolders {
            try? FileManager.default.removeItem(at: directory)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        loadTokenScriptFileIndices()
    }

    deinit {
        try? directoryWatcher?.stop()
    }

    private func loadTokenScriptFileIndices() {
        if let loaded = TokenScriptFileIndices.load(fromUrl: indicesFileUrl) {
            tokenScriptFileIndices = loaded
        }
    }

    private func writeIndicesToDisk() {
        tokenScriptFileIndices.write(toUrl: indicesFileUrl)
    }

    private func xmlWitEntityReferencesUnsubstituted(forContract contract: AlphaWallet.Address) -> (FileContentsHash, String)? {
        if let hash = tokenScriptFileIndices.contractToHashes[contract]?.first, let contents = readXmlWithHash(hash) {
            return (hash, contents)
        } else {
            return nil
        }
    }

    private func readXmlWithHash(_ hash: FileContentsHash) -> String? {
        let path = localUrlForXml(forHash: hash)
        return try? String(contentsOf: path)
    }

    private func localUrlForXml(forHash hash: FileContentsHash) -> URL {
        if let filename = tokenScriptFileIndices.hashToOverridesFilename[hash] {
            return directory.appendingPathComponent(filename)
        } else {
            let filename = "\(hash.value).\(XMLHandler.fileExtension)"
            return directory.appendingPathComponent(filename)
        }
    }

    public func watchOverridesDirectoryContentsForChanges() {
        precondition(!isOfficial)
        guard directoryWatcher == nil else { return }
        directoryWatcher = DirectoryContentsWatcher.Local(path: directory.path)
        try? directoryWatcher?.start { [weak self] results in
            guard let strongSelf = self else { return }
            switch results {
            case .noChanges:
                break
            case .updated(let filenames):
                for each in filenames {
                    let file = FileChange.override(filename: Filename(value: each), directory: strongSelf.directory)
                    strongSelf.handleOverriddenTokenScriptFileChanged(file: file)
                }
            }
        }
    }

    private func purgeCacheFor(contractsAndServers: [AddressAndOptionalRPCServer], schemaUids: [Attestation.SchemaUid]) {
        //Import to clear the signature cache (which includes conflicts) because a file which was in conflict with another earlier might no longer be
        //TODO clear the cache more intelligently rather than purge it entirely. It might be hard or impossible to know which other contracts are affected
        tokenScriptFileIndices.signatureVerificationTypes = .init()
        for each in Array(Set(contractsAndServers)) {
            delegate?.tokenScriptChanged(forContractAndServer: .init(address: each.address, server: nil))
        }
        for each in schemaUids {
            delegate?.tokenScriptChanged(forAttestationSchemaUid: each)
        }
    }

    //We don't call this for overrides since they are AirDrop-ed or some similar means where iOS writes them for us
    private func writeOfficialXmlToFile(hash: FileContentsHash, xml: String) -> Bool {
        precondition(isOfficial)
        let path = localUrlForXml(forHash: hash)
        do {
            try xml.write(to: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            infoLog("[TokenScript] Writing XML to disk failed with XML length: \(xml.count) error: \(error)")
            return false
        }
    }
}

extension AssetDefinitionDiskBackingStore: AssetDefinitionBackingStore {
    public func debugGetPathToScriptUriFile(url: URL) -> URL? {
        guard let hash = tokenScriptFileIndices.urlToHash[url] else { return nil }
        let path = localUrlForXml(forHash: hash)
        return path
    }

    public func getXml(byContract contract: AlphaWallet.Address) -> String? {
        if TokenScript.shouldDisableTokenScriptXMLFileReads {
            return nil
        }
        guard var (hash, xmlContents) = xmlWitEntityReferencesUnsubstituted(forContract: contract) else { return nil }
        //entities are in official TokenScript files, only possible for overrides, but we can check, just a no-op
        guard let entities = tokenScriptFileIndices.hashToEntitiesReferenced[hash] else { return xmlContents }
        for each in entities {
            //Guard against XML entity injection
            guard !each.fileName.value.contains("/") else { continue }
            let url = directory.appendingPathComponent(each.fileName.value)
            guard let contents = try? String(contentsOf: url) else { continue }
            xmlContents = (xmlContents as NSString).replacingOccurrences(of: "&\(each.name);", with: contents)
        }
        return xmlContents
    }

    public func storeOfficialXmlForToken(_ contract: AlphaWallet.Address, xml: String, fromUrl url: URL) {
        precondition(isOfficial)
        if TokenScript.shouldDisableTokenScriptXMLFileWrites { return }
        let hash = functional.hash(contents: xml)
        if writeOfficialXmlToFile(hash: hash, xml: xml) {
            let path = localUrlForXml(forHash: hash)
            let file = FileChange.official(filename: Filename(value: path.lastPathComponent), directory: directory, fromUrl: url, fromAttestation: nil)
            handleOfficialTokenScriptXmlFileChanged(file: file)
        }
    }

    public func isOfficial(contract: AlphaWallet.Address) -> Bool {
        return isOfficial
    }

    ///We don't bother to check if there's a conflict inside this function because if there's a conflict, the files should be ignored anyway
    public func isCanonicalized(contract: AlphaWallet.Address) -> Bool {
        if let hash = tokenScriptFileIndices.contractToHashes[contract]?.first {
            let path = localUrlForXml(forHash: hash)
            return path.path.hasSuffix(".\(XMLHandler.fileExtension)")
        } else {
            //We return true because then it'll be treated as needing a higher security level rather than a non-canonicalized (debug version)
            return true
        }

        return false
    }

    public func hasConflictingFile(forContract contract: AlphaWallet.Address) -> Bool {
        return tokenScriptFileIndices.hasConflictingFile(forContract: contract)
    }

    public func getCacheTokenScriptSignatureVerificationType(forXmlString xmlString: String) -> TokenScriptSignatureVerificationType? {
        return tokenScriptFileIndices.signatureVerificationTypes[functional.hash(contents: xmlString)]
    }

    public func writeCacheTokenScriptSignatureVerificationType(_ verificationType: TokenScriptSignatureVerificationType, forContract contract: AlphaWallet.Address, forXmlString xmlString: String) {
        defer { writeIndicesToDisk() }
        tokenScriptFileIndices.signatureVerificationTypes[functional.hash(contents: xmlString)] = verificationType
    }

    //Must only return the last modified date for a file if it's for the current schema version otherwise, a file using the old schema might have a more recent timestamp (because it was recently downloaded) than a newer version on the server (which was not yet made available by the time the user downloaded the version with the old schema)
    public func lastModifiedDateOfCachedAssetDefinitionFile(forContract contract: AlphaWallet.Address) -> Date? {
        precondition(isOfficial)
        let dates: [Date] = (tokenScriptFileIndices.contractToHashes[contract, default: []]).compactMap { hash in
            let path = localUrlForXml(forHash: hash)
            guard let lastModified = try? path.resourceValues(forKeys: [.contentModificationDateKey]) else { return nil }
            guard XMLHandler.isTokenScriptSupportedSchemaVersion(path) else { return nil }
            return lastModified.contentModificationDate
        }.sorted()
        //Defensive: if there's more than 1, we use the oldest date
        return dates.first
    }

    public func deleteXmlFileDownloadedFromOfficialRepo(forContract contract: AlphaWallet.Address) {
        guard isOfficial else { return }
        guard let oldHashes = tokenScriptFileIndices.contractToHashes[contract] else { return }
        for eachOldHash in oldHashes {
            if let fromUrl = tokenScriptFileIndices.urlToHash.first(where: { $0.value == eachOldHash })?.key {
                let filename = Filename.convertFromOfficialXmlHash(eachOldHash)
                let file = FileChange.official(filename: filename, directory: directory, fromUrl: fromUrl, fromAttestation: nil)
                handleOfficialTokenScriptXmlFileChanged(file: file)
            }
        }
    }

    public func storeOfficialXmlForAttestation(_ attestation: Attestation, withURL url: URL, xml: String) {
        precondition(isOfficial)
        let hash = functional.hash(contents: xml)
        if writeOfficialXmlToFile(hash: hash, xml: xml) {
            let path = localUrlForXml(forHash: hash)
            let file = FileChange.official(filename: Filename(value: path.lastPathComponent), directory: directory, fromUrl: url, fromAttestation: attestation)
            handleOfficialTokenScriptXmlFileChanged(file: file)
        }
    }

    public func getXml(byScriptUri url: URL) -> String? {
        guard let hash = tokenScriptFileIndices.urlToHash[url] else { return nil }
        return readXmlWithHash(hash)
    }

    public func getXmls(bySchemaId schemaUid: Attestation.SchemaUid) -> [String] {
        //TODO performance issue if there's too many (and big) files for the same schema UID. When would it happen?
        return tokenScriptFileIndices.schemaUidToHashes[schemaUid]?.compactMap { readXmlWithHash($0) } ?? []
    }
}

///For adding/removing/modifying TokenScript files (XML and non-XML)
extension AssetDefinitionDiskBackingStore {
    private func handleOfficialTokenScriptXmlFileChanged(file: FileChange) {
        precondition(isOfficial)
        precondition(!file.isOverride)
        //Official TokenScript should be .xml/.tsml and non other file types
        guard file.isXml else { return }
        defer { writeIndicesToDisk() }

        let schemaUidsAffected: [Attestation.SchemaUid]
        let contractsAndServersAffected: [AddressAndOptionalRPCServer]
        //TODO force unwrap due to cyclic references
        (contractsAndServersAffected, tokenScriptFileIndices, schemaUidsAffected) = functional.computeXmlFileChanged(file: file, tokenScriptFileIndices: tokenScriptFileIndices, resolver: resolver!)
        purgeCacheFor(contractsAndServers: contractsAndServersAffected, schemaUids: schemaUidsAffected)
    }

    private func handleOverriddenTokenScriptFileChanged(file: FileChange) {
        precondition(!isOfficial)
        precondition(file.isOverride)
        defer { writeIndicesToDisk() }
        let contractsAndServersAffected: [AddressAndOptionalRPCServer]
        let schemaUidsAffected: [Attestation.SchemaUid]
        if file.isXml {
            //TODO force unwrap due to cyclic references
            (contractsAndServersAffected, tokenScriptFileIndices, schemaUidsAffected) = functional.computeXmlFileChanged(file: file, tokenScriptFileIndices: tokenScriptFileIndices, resolver: resolver!)
        } else {
            schemaUidsAffected = []
            contractsAndServersAffected = functional.computeOverriddenNonXmlFileChanged(file: file, tokenScriptFileIndices: tokenScriptFileIndices)
        }

        purgeCacheFor(contractsAndServers: contractsAndServersAffected, schemaUids: schemaUidsAffected)
        //TODO restore support bookkeeping bad TokenScript files?
        //delegate?.badTokenScriptFilesChanged(in: self)
    }
}

extension AssetDefinitionDiskBackingStore {
    enum functional {}
}

fileprivate extension AssetDefinitionDiskBackingStore.functional {
    //Have to store at the front to "override". This is less important for scriptURIs, but essential for overrides
    static func prependHashToFront(hash: FileContentsHash, list: [FileContentsHash]) -> [FileContentsHash] {
        return [hash] + list
    }

    static func computeOverriddenNonXmlFileChanged(file: FileChange, tokenScriptFileIndices: TokenScriptFileIndices) -> [AddressAndOptionalRPCServer] {
        precondition(file.isOverride)
        precondition(!file.isXml)
        var contractsAndServersAffected: [AddressAndOptionalRPCServer] = []
        let affectedHashes = tokenScriptFileIndices.hashToEntitiesReferenced.filter { _, entities in entities.contains(where: { $0.fileName == file.filename }) }.keys
        for each in affectedHashes {
            let contracts = tokenScriptFileIndices.contractToHashes.filter { $1.contains(each) }.keys
            contractsAndServersAffected.append(contentsOf: contracts.map { AddressAndOptionalRPCServer(address: $0, server: nil) })
        }
        return contractsAndServersAffected
    }

    static func computeAttestationEffectForXmlFileDeleted(oldHash: FileContentsHash, tokenScriptFileIndices: TokenScriptFileIndices) -> (tokenScriptFileIndices: TokenScriptFileIndices, schemaUidsAffected: [Attestation.SchemaUid]) {
        let schemaUidsAffected: [Attestation.SchemaUid] = tokenScriptFileIndices.schemaUidToHashes.compactMap({
            if $0.value.contains(oldHash) {
                return $0.key
            } else {
                return nil
            }
        })
        var indices = tokenScriptFileIndices
        for eachSchemaUid in schemaUidsAffected {
            let hashes = indices.schemaUidToHashes[eachSchemaUid, default: []].filter { $0 != oldHash }
            indices.schemaUidToHashes[eachSchemaUid] = hashes
        }
        return (indices, schemaUidsAffected)
    }

    //When a file is modified, it is considered deleted + new/changed, in order to remove the old index entries
    static func computeXmlFileDeleted(file: FileChange, tokenScriptFileIndices: TokenScriptFileIndices) -> (contractsAndServersAffected: [AddressAndOptionalRPCServer], tokenScriptFileIndices: TokenScriptFileIndices, schemaUidsAffected: [Attestation.SchemaUid]) {
        precondition(file.isXml)
        var indices = tokenScriptFileIndices
        let oldHash: FileContentsHash?
        let schemaUidsAffected: [Attestation.SchemaUid]

        switch file {
        case .official(let filename, _, _, _):
            let hash = FileContentsHash.convertFromOfficialXmlFilename(filename)
            //Check if the hash was previously stored so we can tell if there is an old file or not. The reason there is no old file is this is a new file triggering this delete when there's no old file being replaced. (Updates trigger a delete because they are treated as delete+new/change)
            let isOldHash = indices.urlToHash.contains(where: { $1 == hash })
            if isOldHash {
                oldHash = hash
            } else {
                oldHash = nil
            }
        case .override:
            oldHash = indices.hashToOverridesFilename.first(where: { $1 == file.filename })?.key
        }

        if let oldHash {
            (indices, schemaUidsAffected) = computeAttestationEffectForXmlFileDeleted(oldHash: oldHash, tokenScriptFileIndices: indices)
            indices.urlToHash = indices.urlToHash.filter({ $1 != oldHash })
            indices.hashToOverridesFilename.removeValue(forKey: oldHash)
            indices.hashToEntitiesReferenced.removeValue(forKey: oldHash)
            let copy = indices.schemaUidToHashes
            for (k, hashes) in copy {
                indices.schemaUidToHashes[k] = hashes.filter { $0 != oldHash }
            }
        } else {
            schemaUidsAffected = []
        }

        let contractsPreviouslyForThisXmlFile: [AlphaWallet.Address]
        if let oldHash {
            contractsPreviouslyForThisXmlFile = Array(indices.contractToHashes.filter({ $1.contains(oldHash) }).keys)
        } else {
            contractsPreviouslyForThisXmlFile = []
        }
        for eachContract in contractsPreviouslyForThisXmlFile {
            if var hashes = indices.contractToHashes[eachContract], hashes.count > 1, let oldHash {
                hashes.removeAll { $0 == oldHash }
                indices.contractToHashes[eachContract] = hashes
            } else {
                indices.contractToHashes.removeValue(forKey: eachContract)
            }
        }
        return (contractsPreviouslyForThisXmlFile.map { AddressAndOptionalRPCServer(address: $0, server: nil) }, tokenScriptFileIndices: indices, schemaUidsAffected: schemaUidsAffected)
    }

    static func computeNewOrUpdatedXmlFile(file: FileChange, xml: String, tokenScriptFileIndices: TokenScriptFileIndices, resolver: TokenScriptResolver) -> (contractsAndServersAffected: [AddressAndOptionalRPCServer], tokenScriptFileIndices: TokenScriptFileIndices, schemaUidsAffected: [Attestation.SchemaUid]) {
        precondition(file.isXml)
        var indices = tokenScriptFileIndices
        var schemaUidsAffected = [Attestation.SchemaUid]()
        let contractsPreviouslyForThisXmlFile: [AddressAndOptionalRPCServer]
        (contractsPreviouslyForThisXmlFile, indices, schemaUidsAffected) = computeXmlFileDeleted(file: file, tokenScriptFileIndices: indices)
        let contractsAndServers: [AddressAndOptionalRPCServer]
        let hash = hash(contents: xml)
        let hasHoldingContract: Bool
        let hasAttestationSupport: Bool
        if let holdingContracts: [AddressAndOptionalRPCServer] = XMLHandler.getHoldingContracts(forTokenScript: xml)?.map({ AddressAndOptionalRPCServer(address: $0.0, server: RPCServer(chainID: $0.1)) }) {
            hasHoldingContract = true
            contractsAndServers = holdingContracts
            for eachContractAndServer in contractsAndServers {
                indices.contractToHashes[eachContractAndServer.address] = prependHashToFront(hash: hash, list: indices.contractToHashes[eachContractAndServer.address, default: []])
            }
            switch file {
            case .official(_, _, let url, _):
                indices.urlToHash[url] = hash
            case .override(let filename, _):
                let entities = XMLHandler.getEntities(forTokenScript: xml)
                indices.hashToEntitiesReferenced[hash] = entities
                if let _ = indices.hashToOverridesFilename[hash] {
                    //TODO we didn't delete the file, but it's probably OK
                }
                indices.hashToOverridesFilename[hash] = filename
            }
        } else {
            hasHoldingContract = false
            contractsAndServers = []
        }

        switch file {
        case .official(_, _, let url, let attestation):
            if let attestation {
                let xmlHandler = resolver.xmlHandler(forAttestation: attestation, xmlString: xml)
                if let collectionId = xmlHandler.attestationCollectionId, let schemaUid = xmlHandler.attestationSchemaUid {
                    hasAttestationSupport = true
                    schemaUidsAffected.append(schemaUid)
                    indices.urlToHash[url] = hash
                    indices.schemaUidToHashes[schemaUid] = prependHashToFront(hash: hash, list: indices.schemaUidToHashes[schemaUid, default: []])
                } else {
                    hasAttestationSupport = false
                }
            } else if let collectionId = XMLHandler.getAttestationCollectionId(xmlString: xml), let schemaUid = XMLHandler.getAttestationSchemaUid(xmlString: xml) {
                hasAttestationSupport = true
                schemaUidsAffected.append(schemaUid)
                indices.urlToHash[url] = hash
                indices.schemaUidToHashes[schemaUid] = prependHashToFront(hash: hash, list: indices.schemaUidToHashes[schemaUid, default: []])
            } else {
                hasAttestationSupport = false
            }
        case .override(let filename, _):
            if let collectionId = XMLHandler.getAttestationCollectionId(xmlString: xml), let schemaUid = XMLHandler.getAttestationSchemaUid(xmlString: xml) {
                hasAttestationSupport = true
                schemaUidsAffected.append(schemaUid)
                indices.schemaUidToHashes[schemaUid] = prependHashToFront(hash: hash, list: indices.schemaUidToHashes[schemaUid, default: []])
                indices.hashToOverridesFilename[hash] = filename
            } else {
                hasAttestationSupport = false
            }
        }

        if !hasHoldingContract && !hasAttestationSupport {
            //TODO bad TokenScript file? Do we book keep?
        }

        var contractsAndServersAffected: [AddressAndOptionalRPCServer] = contractsAndServers + contractsPreviouslyForThisXmlFile
        return (contractsAndServersAffected: contractsAndServersAffected, tokenScriptFileIndices: indices, schemaUidsAffected: schemaUidsAffected)
    }

    static func computeXmlFileChanged(file: FileChange, tokenScriptFileIndices: TokenScriptFileIndices, resolver: TokenScriptResolver) -> (contractsAndServersAffected: [AddressAndOptionalRPCServer], tokenScriptFileIndices: TokenScriptFileIndices, schemaUidsAffected: [Attestation.SchemaUid]) {
        precondition(file.isXml)
        if let xml = file.contents {
            return computeNewOrUpdatedXmlFile(file: file, xml: xml, tokenScriptFileIndices: tokenScriptFileIndices, resolver: resolver)
        } else {
            return computeXmlFileDeleted(file: file, tokenScriptFileIndices: tokenScriptFileIndices)
        }
    }

    static func hash(contents: String) -> FileContentsHash {
        //TODO if hashValue changes, doesn't it mean `TokenScriptFileIndices.fileHashes` is broken?
        //String.hashValue is different with each app launch, so we can't use it
        let inputData = Data(contents.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hash: String = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return FileContentsHash(value: hash)
    }
}

fileprivate enum FileChange {
    //Not having fromAttestation only means it's not triggered by an attestation. Doesn't mean the TokenScript can't be applied to one
    case official(filename: Filename, directory: URL, fromUrl: URL, fromAttestation: Attestation?)
    case override(filename: Filename, directory: URL)

    private var localUrl: URL {
        switch self {
        case .official(let filename, let directory, _, _):
            return directory.appendingPathComponent(filename)
        case .override(let filename, let directory):
            return directory.appendingPathComponent(filename)
        }
    }

    var isOfficial: Bool {
        switch self {
        case .official:
            return true
        case .override:
            return false
        }
    }

    var isOverride: Bool {
        return !isOfficial
    }

    var filename: Filename {
        switch self {
        case .official(let filename, _, _, _):
            return filename
        case .override(let filename, _):
            return filename
        }
    }

    //Useful in debugger
    var attestation: Attestation? {
        switch self {
        case .official(_, _, _, let attestation):
            return attestation
        case .override:
            return nil
        }
    }

    var contents: String? {
        return try? String(contentsOf: localUrl)
    }

    var isXml: Bool {
        return XMLHandler.hasValidTokenScriptFileExtension(url: localUrl)
    }
}
