//
//  SaveCustomRpcBrowseDataController.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit

protocol SaveCustomRpcBrowseDataObserver: class {
    func dataHasChanged(rows: Int)
    func selectedServers() -> [CustomRPC]
}

class SaveCustomRpcBrowseDataController: NSObject {

    // MARK: - Properties
    // MARK: Private

    private let originalCustomRpcList: [CustomRPC]
    private var mainnetCustomRpcList: [CustomRPC] = []
    private var testnetCustomRpcList: [CustomRPC] = []
    private var tableViewSection: [CustomRpcTableViewSection] = []
    private var mainnetTableViewSection: CustomRpcTableViewSection?
    private var testnetTableViewSection: CustomRpcTableViewSection?

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

// MARK: - UITableViewDataSource

extension SaveCustomRpcBrowseDataController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return tableViewSection.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section < tableViewSection.count else { return 0 }
        return tableViewSection[section].rows()
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.section < tableViewSection.count else { return UITableViewCell() }
        let section = tableViewSection[indexPath.section]
        return section.cellAt(row: indexPath.row, from: tableView)
    }

}

// MARK: - UITableViewDelegate

extension SaveCustomRpcBrowseDataController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section < tableViewSection.count else { return }
        tableViewSection[indexPath.section].didSelect(row: indexPath.row)
        tableView.reloadRows(at: [indexPath], with: .automatic)
        configurationDelegate?.enableAddFunction(!selectedServers().isEmpty)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection sectionIndex: Int) -> UIView? {
        guard sectionIndex < tableViewSection.count else { return nil }
        return tableViewSection[sectionIndex].headerView()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section < tableViewSection.count else { return 0 }
        return tableViewSection[section].headerHeight()
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        0
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }

}

// MARK: - EnableServerHeaderViewDelegate

extension SaveCustomRpcBrowseDataController: EnableServersHeaderViewDelegate {

    func toggledTo(_ isEnabled: Bool, headerView: EnableServersHeaderView) {
        switch (headerView.mode, isEnabled) {
        case (.mainnet, true), (.testnet, false):
            switchToMainnet()
        case (.mainnet, false), (.testnet, true):
            switchToTestnet()
        }
        dataObserver?.dataHasChanged(rows: currentRowCount)
        configurationDelegate?.enableAddFunction(!selectedServers().isEmpty)
    }

    private func switchToMainnet() {
        mainnetTableViewSection?.enableSection()
        testnetTableViewSection?.disableSection()
    }

    private func switchToTestnet() {
        testnetTableViewSection?.enableSection()
        mainnetTableViewSection?.disableSection()
    }

}
