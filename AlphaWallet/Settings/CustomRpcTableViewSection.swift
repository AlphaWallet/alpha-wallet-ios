//
//  CustomRpcTableViewSection.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 21/12/21.
//

import UIKit
import AlphaWalletFoundation

// A TableViewSection represents a section from a tableview. The tableview delegate methods are passed from the delegate to the section so customization behaviour for different sections is easier.

class CustomRpcTableViewSection: NSObject, TableViewSection {

    // MARK: - Properties

    // MARK: Private

    private let mode: EnabledServersViewModel.Mode
    private var customRpcList: [CustomRPC] = []
    private var enabled: Bool = true
    private var filtered: Bool = false
    private var filteredList: [CustomRPC] = []
    private var markedCustomRpcIdList: Set<Int> = Set([])
    private weak var headerViewDelegate: EnableServersHeaderViewDelegate?

    // MARK: - Constructors

    init(customRpcList: [CustomRPC], mode: EnabledServersViewModel.Mode, headerViewDelegate: EnableServersHeaderViewDelegate) {
        self.customRpcList = customRpcList
        self.mode = mode
        self.headerViewDelegate = headerViewDelegate
        super.init()
    }

    // MARK: - TableView functions

    func rows() -> Int {
        guard enabled else { return 0 }
        return filtered ? filteredList.count : customRpcList.count
    }

    func serverAt(row: Int) -> CustomRPC {
        let selectedRow = filtered ? filteredList[row] : customRpcList[row]
        return selectedRow
    }

    func didSelect(row: Int) {
        let chainId = filtered ? filteredList[row].chainID : customRpcList[row].chainID
        if isMarked(chainID: chainId) {
            removeMarked(chainId: chainId)
        } else {
            addMarked(chainID: chainId)
        }
    }

    func resetFilter() -> Int {
        guard enabled else { return 0 }
        filtered = false
        filteredList = []
        return customRpcList.count
    }

    func filter(phrase: String) -> Int {
        filteredList = customRpcList.filter { customRpc in
            return customRpc.match(any: phrase)
        }
        filtered = true
        // We do the actual filtering so that when the user switches from mainnet to testnet and vice versa, the results are there immediately. This saves a round trip from the View Controller telling this object to filter again.
        guard enabled else { return 0 }
        return filteredList.count
    }

    func headerView() -> UIView? {
        guard let headerViewDelegate = headerViewDelegate else {
            return nil
        }
        switch mode {
        case .mainnet:
            return EnableServersHeaderView.mainnet(enabled: enabled, delegate: headerViewDelegate)
        case .testnet:
            return EnableServersHeaderView.testnet(enabled: enabled, delegate: headerViewDelegate)
        }
    }

    func headerHeight() -> CGFloat {
        return Style.RPCServerTableView.HeaderHeight
    }

    func disableSection() {
        enabled = false
    }

    func enableSection() {
        enabled = true
    }

    func isEnabled() -> Bool {
        return enabled
    }

    func isMarked(chainID: Int) -> Bool {
        return markedCustomRpcIdList.contains(chainID)
    }

    func addMarked(chainID: Int) {
        markedCustomRpcIdList.insert(chainID)
    }

    func removeMarked(chainId: Int) {
        markedCustomRpcIdList.remove(chainId)
    }

    func selectedServers() -> [CustomRPC] {
        return customRpcList.compactMap { customRpc in
            markedCustomRpcIdList.contains(customRpc.chainID) ? customRpc : nil
        }
    }

    func remove(customRpcs toBeRemoved: [CustomRPC]) {
        let set = Set(toBeRemoved.map({ customRpc in
            customRpc.chainID
        }))
        // remove from customRpcList
        customRpcList.removeAll { customRpc in
            set.contains(customRpc.chainID)
        }
        // remove from filteredList
        filteredList.removeAll { customRpc in
            set.contains(customRpc.chainID)
        }
        // remove from markedCustomRpcIdList
        set.forEach { id in
            markedCustomRpcIdList.remove(id)
        }
    }

}

// MARK: - Filter functions

fileprivate extension CustomRPC {

    func match(any rawPhrase: String) -> Bool {
        guard !rawPhrase.isEmpty else { return true }
        let phrase = rawPhrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return match(chainId: phrase) || match(nativeCryptoTokenName: phrase) || match(chainName: phrase) || match(symbol: phrase)
    }

    func match(chainId phrase: String) -> Bool {
        let idString = String(self.chainID)
        return idString.lowercased().contains(phrase)
    }

    func match(nativeCryptoTokenName phrase: String) -> Bool {
        guard let name = self.nativeCryptoTokenName else { return false }
        return name.lowercased().contains(phrase)
    }

    func match(chainName phrase: String) -> Bool {
        return self.chainName.lowercased().contains(phrase)
    }

    func match(symbol phrase: String) -> Bool {
        guard let symbol = self.symbol else { return false }
        return symbol.lowercased().contains(phrase)
    }

    func match(rpcEndPoint phrase: String) -> Bool {
        return self.rpcEndpoint.lowercased().contains(phrase)
    }

    func match(explorerEndpoint phrase: String) -> Bool {
        guard let explorerEndpoint = self.explorerEndpoint else { return false }
        return explorerEndpoint.lowercased().contains(phrase)
    }

}

// MARK: - Creation

fileprivate extension EnableServersHeaderView {

    static func mainnet(enabled: Bool, delegate: EnableServersHeaderViewDelegate) -> EnableServersHeaderView {
        return enabledHeadersView(mode: .mainnet, enabled: enabled, delegate: delegate)
    }

    static func testnet(enabled: Bool, delegate: EnableServersHeaderViewDelegate) -> EnableServersHeaderView {
        return enabledHeadersView(mode: .testnet, enabled: enabled, delegate: delegate)
    }

}

// TODO: Can a cache be employed to reduce memory load? Future optimization.

fileprivate func enabledHeadersView(mode: EnabledServersViewModel.Mode, enabled: Bool, delegate: EnableServersHeaderViewDelegate) -> EnableServersHeaderView {
    let header = EnableServersHeaderView()
    header.configure(mode: mode, isEnabled: enabled)
    header.delegate = delegate
    return header
}
