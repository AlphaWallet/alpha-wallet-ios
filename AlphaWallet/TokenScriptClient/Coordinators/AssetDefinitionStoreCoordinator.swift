// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

protocol AssetDefinitionStoreCoordinatorDelegate: class {
    func show(error: Error, for viewController: AssetDefinitionStoreCoordinator)
    func addedTokenScript(forContract contract: AlphaWallet.Address, forServer server: RPCServer, destinationFileInUse: Bool, filename: String)
}

struct SchemaCheckError: LocalizedError {
    var msg: String
    var errorDescription: String? {
        return msg
    }
}

enum OpenURLError: Error {
    case unsupportedTokenScriptVersion
    case copyTokenScriptURL(_ url: URL, _ destinationURL: URL, error: Error)

    var localizedDescription: String {
        switch self {
        case .unsupportedTokenScriptVersion:
            return R.string.localizable.tokenScriptNotSupportedSchemaError()
        case .copyTokenScriptURL(let url, let destinationFileName, let error):
            return R.string.localizable.tokenScriptMoveFileError(url.path, destinationFileName.path, error.localizedDescription)
        }
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

    private var inboxContents: [URL]? {
        guard let inboxDirectory = AssetDefinitionStoreCoordinator.inboxDirectory else { return nil }
        return try? FileManager.default.contentsOfDirectory(at: inboxDirectory, includingPropertiesForKeys: nil)
    }

    private var overrides: [URL]? {
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
        vc.hidesBottomBarWhenPushed = true
        configure(overridesViewController: vc)
        viewControllers.append(WeakRef(object: vc))
        return vc
    }

    func configure(overridesViewController: AssetDefinitionsOverridesViewController) {
        if let contents = overrides {
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
        guard let contents = inboxContents else { return }
        for each in contents {
            try? FileManager.default.removeItem(at: each)
         }
    }

    ///For development
    private func printInboxContents() {
        guard let contents = inboxContents else { return }
        NSLog("Contents of inbox:")
        for each in contents {
            NSLog("  In inbox: \(each)")
        }
    }

    /// Return true if handled
    func handleOpen(url: URL) -> Bool {
        guard let overridesDirectory = AssetDefinitionStoreCoordinator.overridesDirectory else { return false }
        //Guard against replacing the indices file. This shouldn't be possible because we should have configured the app to only accept AirDrops for files with known extensions. This is purely defensive
        guard url.lastPathComponent != TokenScript.indicesFileName else {
            try? FileManager.default.removeItem(at: url)
            return true
        }

        //TODO improve or remove checking here. getHoldingContracts() below already check for schema support. We might have to show the error in wallet if we keep the file instead. We are deleting the files for now
        let isTokenScriptOrXml: Bool
        switch XMLHandler.checkTokenScriptSchema(forPath: url) {
        case .supportedTokenScriptVersion:
            isTokenScriptOrXml = true
        case .unsupportedTokenScriptVersion:
            try? FileManager.default.removeItem(at: url)
            delegate?.show(error: OpenURLError.unsupportedTokenScriptVersion, for: self)

            return true
        case .unknownXml:
            try? FileManager.default.removeItem(at: url)
            return true
        case .others:
            isTokenScriptOrXml = false
        }

        let filename = url.lastPathComponent
        let destinationFileName = overridesDirectory.appendingPathComponent(filename)
        let destinationFileInUse = overrides?.contains(destinationFileName) ?? false

        do {
            try? FileManager.default.removeItem(at: destinationFileName )
            try FileManager.default.moveItem(at: url, to: destinationFileName )
            if isTokenScriptOrXml, let contents = try? String(contentsOf: destinationFileName) {
                if let contracts = XMLHandler.getHoldingContracts(forTokenScript: contents) {
                    for (contract, chainId) in contracts {
                        let server = RPCServer(chainID: chainId)
                        delegate?.addedTokenScript(forContract: contract, forServer: server, destinationFileInUse: destinationFileInUse, filename: filename)
                    }
                } 

                return true
            }
        } catch {
            delegate?.show(error: OpenURLError.copyTokenScriptURL(url, destinationFileName, error: error), for: self)
        }

        return false
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
        viewController.showShareActivity(fromSource: .view(viewController.view), with: [file])
    }
}
