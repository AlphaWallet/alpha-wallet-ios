// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class ConsoleCoordinator: Coordinator {
    private let assetDefinitionStore: AssetDefinitionStore

    var coordinators: [Coordinator] = []

    init(assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
    }

    func createConsoleViewController() -> ConsoleViewController {
        let vc = ConsoleViewController()
        vc.hidesBottomBarWhenPushed = true
        //TODO console just show the list of files at the moment
        let bad = assetDefinitionStore.listOfBadTokenScriptFiles.map { "\($0) is invalid" }
        let conflicts = assetDefinitionStore.listOfConflictingTokenScriptFiles.map { "\($0) has a conflict" }
        vc.configure(messages: bad + conflicts)
        return vc
    }

    func start() {
        //do nothing
    }
}
