// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol AssetDefinitionStoreCoordinatorDelegate: class {
    func show(error: Error, for viewController: AssetDefinitionStoreCoordinator)
    func addedTokenScript(forContract contract: AlphaWallet.Address, forServer server: RPCServer)
}

struct SchemaCheckError: LocalizedError {
    var msg: String
    var errorDescription: String? {
        return msg
    }
}

class AssetDefinitionStoreCoordinator: Coordinator {
    private class WeakRef<T: AnyObject> {
        weak var object: T?
        init(object: T) {
            self.object = object
        }
    }

    private static var inboxDirectory: URL? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        guard let documentDirectory = paths.first else { return nil }
        return documentDirectory.appendingPathComponent("Inbox")
    }
    private static var overridesDirectory: URL? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        guard let documentDirectory = paths.first else { return nil }
        return documentDirectory.appendingPathComponent(AssetDefinitionDiskBackingStoreWithOverrides.overridesDirectoryName)
    }
    private let assetDefinitionStore: AssetDefinitionStore
    private var directoryWatcher: DirectoryContentsWatcherProtocol?
    //Holds an array of weak references. This exists basically because we didn't implement a way to detect when view controllers in this list are destroyed
    private var viewControllers: [WeakRef<AssetDefinitionsOverridesViewController>] = []

    weak var delegate: AssetDefinitionStoreCoordinatorDelegate?
    var coordinators: [Coordinator] = []

    init(assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
    }

    deinit {
        try? directoryWatcher?.stop()
    }

    func createOverridesViewController() -> AssetDefinitionsOverridesViewController {
        let vc = AssetDefinitionsOverridesViewController(fileExtension: AssetDefinitionDiskBackingStore.fileExtension)
        vc.title = R.string.localizable.aHelpAssetDefinitionOverridesTitle()
        vc.delegate = self
        configure(overridesViewController: vc)
        viewControllers.append(WeakRef(object: vc))
        return vc
    }

    func configure(overridesViewController: AssetDefinitionsOverridesViewController) {
        if let contents = overrides() {
            overridesViewController.configure(overriddenURLs: contents)
        } else {
            overridesViewController.configure(overriddenURLs: [])
        }
    }

    func start() {
        deleteInboxContents()
        watchDirectoryContents {
            for each in self.viewControllers {
                if let viewController = each.object {
                    self.configure(overridesViewController: viewController)
                }
            }
        }
    }

    private func deleteInboxContents() {
        guard let contents = inboxContents() else { return }
        for each in contents {
            try? FileManager.default.removeItem(at: each)
         }
    }

    private func inboxContents() -> [URL]? {
        guard let inboxDirectory = AssetDefinitionStoreCoordinator.inboxDirectory else { return nil }
        return try? FileManager.default.contentsOfDirectory(at: inboxDirectory, includingPropertiesForKeys: nil)
    }

    private func overrides() -> [URL]? {
        guard let overridesDirectory = AssetDefinitionStoreCoordinator.overridesDirectory else { return nil }
        let urls = try? FileManager.default.contentsOfDirectory(at: overridesDirectory, includingPropertiesForKeys: nil)
        if var urls = urls {
            if let index = urls.firstIndex(where: { $0.lastPathComponent == TokenScript.indicesFileName }) {
                urls.remove(at: index)
            }
            return urls.sorted { $0.path.caseInsensitiveCompare($1.path) == .orderedAscending }
        } else {
            return nil
        }
    }

    ///For development
    private func printInboxContents() {
        guard let contents = inboxContents() else { return }
        NSLog("Contents of inbox:")
        for each in contents {
            NSLog("  In inbox: \(each)")
        }
    }

    /// Return true if handled
    func handleOpen(url: URL) -> Bool {
        guard let overridesDirectory = AssetDefinitionStoreCoordinator.overridesDirectory else { return false }
        //TODO improve or remove checking here. getHoldingContracts() below already check for schema support. We might have to show the error in wallet if we keep the file instead. We are deleting the files for now
        let isTokenScriptOrXml: Bool
        switch XMLHandler.checkTokenScriptSchema(forPath: url) {
        case .supportedTokenScriptVersion:
            isTokenScriptOrXml = true
        case .unsupportedTokenScriptVersion(let isOld):
            try? FileManager.default.removeItem(at: url)
            delegate?.show(error: SchemaCheckError(msg: R.string.localizable.tokenScriptNotSupportedSchemaError()), for: self)
            return true
        case .unknownXml:
            try? FileManager.default.removeItem(at: url)
            return true
        case .others:
            isTokenScriptOrXml = false
        }

        let filename = url.lastPathComponent
        let destinationFileName = overridesDirectory.appendingPathComponent(filename)
        do {
            try? FileManager.default.removeItem(at: destinationFileName )
            try FileManager.default.moveItem(at: url, to: destinationFileName )
            if isTokenScriptOrXml, let contents = try? String(contentsOf: destinationFileName) {
                if let contracts = XMLHandler.getHoldingContracts(forTokenScript: contents) {
                    for (contract, chainId) in contracts {
                        let server = RPCServer(chainID: chainId)
                        delegate?.addedTokenScript(forContract: contract, forServer: server)
                    }
                }
            }
        } catch {
            NSLog("Error moving asset definition file from \(url.path) to: \(destinationFileName.path): \(error)")
        }
        return true
    }

    private func watchDirectoryContents(changeHandler: @escaping () -> Void) {
        guard directoryWatcher == nil else { return }
        guard let directory = AssetDefinitionStoreCoordinator.overridesDirectory else { return }
        directoryWatcher = DirectoryContentsWatcher.Local(path: directory.path)
        do {
            try directoryWatcher?.start { [weak self] results in
                guard self != nil else { return }
                switch results {
                case .noChanges:
                    break
                case .updated:
                    changeHandler()
                }
            }
        } catch {
        }
    }
}

extension AssetDefinitionStoreCoordinator: AssetDefinitionsOverridesViewControllerDelegate {
    func didDelete(overrideFileForContract file: URL, in viewController: AssetDefinitionsOverridesViewController) {
        try? FileManager.default.removeItem(at: file)
        configure(overridesViewController: viewController)
    }

    func didTapShare(file: URL, in viewController: AssetDefinitionsOverridesViewController) {
        viewController.showShareActivity(from: UIView(), with: [file])
    }
}
