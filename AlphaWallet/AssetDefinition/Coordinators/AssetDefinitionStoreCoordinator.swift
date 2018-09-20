import Foundation

class AssetDefinitionStoreCoordinator: Coordinator {
    var coordinators: [Coordinator] = []
    private static var inboxDirectory: URL? {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        guard let documentDirectory = paths.first else { return nil}
        return documentDirectory.appendingPathComponent("Inbox")
    }

    func start() {
        deleteInboxContents()
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
        guard AssetDefinitionDiskBackingStore.isValidAssetDefinitionFilename(forPath: url) else { return false }
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).compactMap { URL(fileURLWithPath: $0) }
        guard let documentDirectory = paths.first else { return false}

        let overridesDirectory = documentDirectory.appendingPathComponent(AssetDefinitionDiskBackingStoreWithOverrides.overridesDirectoryName)
        let filename = url.lastPathComponent.lowercased()
        let destinationFileName = overridesDirectory.appendingPathComponent(filename)
        do {
            try? FileManager.default.removeItem(at: destinationFileName )
            try FileManager.default.moveItem(at: url, to: destinationFileName )
        } catch {
            NSLog("Error moving asset definition file from \(url.path) to: \(destinationFileName.path): \(error)")
        }
        return true
    }
}
