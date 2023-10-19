//
//  TokenScriptOverridesFileManager.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 29.11.2022.
//

import Foundation
import Combine
import AlphaWalletTokenScript
import AlphaWalletCore
import AlphaWalletLogger

public typealias ImportTokenScriptOverridesFileEvent = Result<TokenScriptOverridesForContract, OpenURLError>
public typealias TokenScriptOverridesForContract = (contract: AlphaWallet.Address, server: RPCServer, destinationFileInUse: Bool, filename: String)

public class TokenScriptOverridesFileManager {
    private static let overridesDirectoryName = "assetDefinitionsOverrides"
    private static let inboxDirectoryName = "Inbox"

    private let rootDirectory: FileManager.SearchPathDirectory
    private lazy var inboxDirectory: URL? = {
        let paths = NSSearchPathForDirectoriesInDomains(rootDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        guard let documentDirectory = paths.first else { return nil }
        return documentDirectory.appendingPathComponent(TokenScriptOverridesFileManager.inboxDirectoryName)
    }()
    private lazy var overridesDirectory: URL? = {
        let paths = NSSearchPathForDirectoriesInDomains(rootDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        guard let documentDirectory = paths.first else { return nil }
        return documentDirectory.appendingPathComponent(TokenScriptOverridesFileManager.overridesDirectoryName)
    }()

    private var inboxContents: [URL]? {
        guard let inboxDirectory = inboxDirectory else { return nil }
        return try? fileManager.contentsOfDirectory(at: inboxDirectory, includingPropertiesForKeys: nil)
    }
    private let importTokenScriptOverridesFileSubject: PassthroughSubject<ImportTokenScriptOverridesFileEvent, Never> = .init()
    private lazy var overridesSubject: CurrentValueSubject<[URL], Never> = .init(getAllOverridesInDirectory())
    private var directoryWatcher: DirectoryContentsWatcherProtocol?
    private let fileManager: FileManager = .default

    public var overrides: AnyPublisher<[URL], Never> {
        overridesSubject.eraseToAnyPublisher()
    }

    public var importTokenScriptOverridesFileEvent: AnyPublisher<Result<TokenScriptOverridesForContract, OpenURLError>, Never> {
        return importTokenScriptOverridesFileSubject.eraseToAnyPublisher()
    }

    public init(rootDirectory: FileManager.SearchPathDirectory = .documentDirectory) {
        self.rootDirectory = rootDirectory
    }

    private func notifyImportTokenScriptOverrides(with result: Result<TokenScriptOverridesForContract, OpenURLError>) {
        importTokenScriptOverridesFileSubject.send(result)
    }

    /// Return true if handled
    @discardableResult public func importTokenScriptOverrides(url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        guard let overridesDirectory = overridesDirectory else { return false }
        //Guard against replacing the indices file. This shouldn't be possible because we should have configured the app to only accept AirDrops for files with known extensions. This is purely defensive
        guard url.lastPathComponent != TokenScript.indicesFileName else {
            //TODO: It is OK to delete the file because it is just named like the indices file, but not actually it. It is in the inbox. But maybe we should check that the actual indices file URL isn't provided here
            try? fileManager.removeItem(at: url)
            return true
        }

        //TODO improve or remove checking here. getHoldingContracts() below already check for schema support. We might have to show the error in wallet if we keep the file instead. We are deleting the files for now
        let isTokenScriptOrXml: Bool
        switch XMLHandler.checkTokenScriptSchema(forPath: url) {
        case .supportedTokenScriptVersion:
            isTokenScriptOrXml = true
        case .unsupportedTokenScriptVersion:
            try? fileManager.removeItem(at: url)
            notifyImportTokenScriptOverrides(with: .failure(.unsupportedTokenScriptVersion))

            return true
        case .unknownXml:
            try? fileManager.removeItem(at: url)
            return true
        case .others:
            isTokenScriptOrXml = false
        }

        let filename = url.lastPathComponent
        let destinationFileName = overridesDirectory.appendingPathComponent(filename)
        let destinationFileInUse = getAllOverridesInDirectory().contains(destinationFileName)

        do {
            //TODO would this removal would trigger an unnecessary change due to other watchers? Can't we just replace the file? But used to be like that
            try? FileManager.default.removeItem(at: destinationFileName )
            try FileManager.default.copyItem(at: url, to: destinationFileName)
            if isTokenScriptOrXml, let contents = try? String(contentsOf: destinationFileName) {
                //TODO this could include support for attestation too? This is a lot like AssetDefinitionStore.handleDownloadedOfficialTokenScript() which is for official?
                //TODO maybe these logic should be in somewhere else
                if let contracts = XMLHandler.getHoldingContracts(forTokenScript: contents) {
                    for (contract, chainId) in contracts {
                        let server = RPCServer(chainID: chainId)
                        notifyImportTokenScriptOverrides(with: .success((contract: contract, server: server, destinationFileInUse: destinationFileInUse, filename: filename)))
                    }
                }

                return true
            }
        } catch {
            notifyImportTokenScriptOverrides(with: .failure(.copyTokenScriptURL(url, destinationFileName, error: error)))
        }

        return false
    }

    public func stop() {
        try? directoryWatcher?.stop()
    }

    public func start() {
        deleteInboxContents()
        watchDirectoryContents()
    }

    private func getAllOverridesInDirectory() -> [URL] {
        guard let overridesDirectory = overridesDirectory else { return [] }
        if var urls = try? fileManager.contentsOfDirectory(at: overridesDirectory, includingPropertiesForKeys: nil) {
            if let index = urls.firstIndex(where: { $0.lastPathComponent == TokenScript.indicesFileName }) {
                urls.remove(at: index)
            }
            if let index = urls.firstIndex(where: { $0.lastPathComponent == ".DS_Store" }) {
                urls.remove(at: index)
            }
            return urls.sorted { $0.path.caseInsensitiveCompare($1.path) == .orderedAscending }
        } else {
            return []
        }
    }

    private func invalidateTokenScriptOverrides() {
        overridesSubject.value = getAllOverridesInDirectory()
    }

    public func remove(overrideFile url: URL) {
        //TODO remove TokenScript files here from the UI. Hide to handle both token or contract?
        try? FileManager.default.removeItem(at: url)
        invalidateTokenScriptOverrides()
    }

    /// For development
    private func printInboxContents() {
        guard let contents = inboxContents else { return }
        debugLog("Contents of inbox:")
        for each in contents {
            debugLog("  In inbox: \(each)")
        }
    }

    private func watchDirectoryContents() {
        guard directoryWatcher == nil else { return }
        guard let directory = overridesDirectory else { return }
        let watcher = DirectoryContentsWatcher.Local(path: directory.path)
        do {
            //This is to watch when overrides directory is changed, for displaying/refreshing the list of overrides screen
            try watcher.start { [weak self] results in
                switch results {
                case .noChanges: break
                case .updated: self?.invalidateTokenScriptOverrides() }
            }
        } catch {

        }

        directoryWatcher = watcher
    }

    private func deleteInboxContents() {
        guard let contents = inboxContents else { return }
        for each in contents {
            try? fileManager.removeItem(at: each)
         }
    }
}
