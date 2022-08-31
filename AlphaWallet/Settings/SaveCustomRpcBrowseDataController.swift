//
//  SaveCustomRpcBrowseDataController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit
import AlphaWalletFoundation

protocol SaveCustomRpcBrowseDataObserver: class {
    func dataHasChanged(rows: Int)
    func selectedServers() -> [CustomRPC]
}

class SaveCustomRpcBrowseDataController: NSObject {

    // MARK: - Properties
    // MARK: Private

    private let originalCustomRpcList: [CustomRPC]
    private (set) var mainnetCustomRpcList: [CustomRPC] = []
    private (set) var testnetCustomRpcList: [CustomRPC] = []
    private (set) var tableViewSection: [CustomRpcTableViewSection] = []
    private (set) var mainnetTableViewSection: CustomRpcTableViewSection?
    private (set) var testnetTableViewSection: CustomRpcTableViewSection?

    // MARK: Public

    weak var dataObserver: SaveCustomRpcBrowseDataObserver?
    weak var configurationDelegate: SaveCustomRpcBrowseViewControllerConfigurationDelegate?

    // MARK: Computed

    var currentRowCount: Int {
        return tableViewSection.reduce(0) { counter, section in
            counter + section.rows()
        }
    }

    // MARK: - Constructors

    init(customRpcs: [CustomRPC], dataObserver: SaveCustomRpcBrowseDataObserver? = nil) {
        self.originalCustomRpcList = customRpcs.sorted(by: { prev, next in
            return prev.chainID < next.chainID
        })
        self.dataObserver = dataObserver
        super.init()
        filterIntoMainnetAndTestnetLists()
        createSections()
    }

    // MARK: - List manipulation

    private func filterIntoMainnetAndTestnetLists() {
        testnetCustomRpcList = []
        mainnetCustomRpcList = []
        originalCustomRpcList.forEach { customRpc in
            switch customRpc.isTestnet {
            case true:
                testnetCustomRpcList.append(customRpc)
            case false:
                mainnetCustomRpcList.append(customRpc)
            }
        }
    }

    private func createSections() {
        let mainnetSection = CustomRpcTableViewSection(customRpcList: mainnetCustomRpcList, mode: .mainnet, headerViewDelegate: self)
        mainnetSection.enableSection()
        mainnetTableViewSection = mainnetSection
        let testnetSection = CustomRpcTableViewSection(customRpcList: testnetCustomRpcList, mode: .testnet, headerViewDelegate: self)
        testnetSection.disableSection()
        testnetTableViewSection = testnetSection
        tableViewSection.append(contentsOf: [mainnetSection, testnetSection])
    }

    // MARK: - Search

    func filter(phrase: String) {
        let count = tableViewSection.reduce(0) { counter, section in
            counter + section.filter(phrase: phrase)
        }
        dataObserver?.dataHasChanged(rows: count)
    }

    func reset() {
        let count = tableViewSection.reduce(0) { counter, section in
            counter + section.resetFilter()
        }
        dataObserver?.dataHasChanged(rows: count)
    }

    // MARK: - Selection

    func selectedServers() -> [CustomRPC] {
        if let mainnetTableViewSection = mainnetTableViewSection, mainnetTableViewSection.isEnabled() {
            return mainnetTableViewSection.selectedServers()
        }
        if let testnetTableViewSection = testnetTableViewSection, testnetTableViewSection.isEnabled() {
            return testnetTableViewSection.selectedServers()
        }
        return []
    }

    // MARK: - Remove CustomRPC

    func remove(customRpcs: [CustomRPC]) {
        tableViewSection.forEach { section in
            section.remove(customRpcs: customRpcs)
        }
    }

}
