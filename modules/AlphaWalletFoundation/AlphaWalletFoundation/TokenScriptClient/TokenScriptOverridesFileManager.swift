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
        guard let overridesDirectory = overridesDirectory else { return false }
        //Guard against replacing the indices file. This shouldn't be possible because we should have configured the app to only accept AirDrops for files with known extensions. This is purely defensive
        guard url.lastPathComponent != TokenScript.indicesFileName else {
            try? fileManager.removeItem(at: url)
            return true
        }

        //TODO improve or remove checking here. getHoldingContracts() below already check for schema support. We might have to show the error in wallet if we keep the file instead. We are deleting the files for now
        let isTokenScriptOrXml: Bool
        switch XMLHandler.functional.checkTokenScriptSchema(forPath: url) {
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
            try? FileManager.default.removeItem(at: destinationFileName )
            try FileManager.default.moveItem(at: url, to: destinationFileName )
            if isTokenScriptOrXml, let contents = try? String(contentsOf: destinationFileName) {
                if let contracts = XMLHandler.functional.getHoldingContracts(forTokenScript: contents) {
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
            return urls.sorted { $0.path.caseInsensitiveCompare($1.path) == .orderedAscending }
        } else {
            return []
        }
    }

    private func invalidateTokenScriptOverrides() {
        overridesSubject.value = getAllOverridesInDirectory()
    }

    public func remove(overrideFile url: URL) {
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
