// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import AlphaWalletTokenScript
import PromiseKit

private struct HasNoTokenScriptLocalRefs: TokenScriptLocalRefsSource {
    var localRefs: [AttributeId: AssetInternalValue] {
        return .init()
    }
}

//NoViewCardTokenScriptActionCoordinator works without being added to a parent coordinator (so far). Which simplifies clean up
class NoViewCardTokenScriptActionCoordinator: Coordinator {
    private let token: Token
    private let tokenHolder: TokenHolder
    private let action: TokenInstanceAction
    private let title: String
    private let viewHtml: (html: String, urlFragment: String?, style: String)
    private let attributes: [AttributeId: AssetAttribute]
    private let transactionFunction: FunctionOrigin?
    private let selection: TokenScriptSelection?
    private let navigationController: UINavigationController
    private let assetDefinitionStore: AssetDefinitionStore
    private let session: WalletSession
    private let keystore: Keystore

    var coordinators: [Coordinator] = []
    weak var delegate: ConfirmTokenScriptActionTransactionDelegate?

    init(token: Token, tokenHolder: TokenHolder, action: TokenInstanceAction, title: String, viewHtml: (html: String, urlFragment: String?, style: String), attributes: [AttributeId: AssetAttribute], transactionFunction: FunctionOrigin?, selection: TokenScriptSelection?, navigationController: UINavigationController, assetDefinitionStore: AssetDefinitionStore, session: WalletSession, keystore: Keystore) {
        self.token = token
        self.tokenHolder = tokenHolder
        self.action = action
        self.title = title
        self.viewHtml = viewHtml
        self.attributes = attributes
        self.transactionFunction = transactionFunction
        self.selection = selection
        self.navigationController = navigationController
        self.assetDefinitionStore = assetDefinitionStore
        self.session = session
        self.keystore = keystore
    }

    func start() {
        performTokenScriptTransactionForNoViewCard()
    }

    private func performTokenScriptTransactionForNoViewCard() {
        let tokenId = tokenHolder.tokens[0].id
        let fetchUserEntries: [Promise<Any?>] = .init()
        let userEntryIds: [String] = .init()
        TokenScript.performTokenScriptAction(action, token: token, tokenId: tokenId, tokenHolder: tokenHolder, userEntryIds: userEntryIds, fetchUserEntries: fetchUserEntries, localRefsSource: HasNoTokenScriptLocalRefs(), assetDefinitionStore: assetDefinitionStore, keystore: keystore, server: token.server, session: session, confirmTokenScriptActionTransactionDelegate: self, navigationController: navigationController)
    }
}

extension NoViewCardTokenScriptActionCoordinator: ConfirmTokenScriptActionTransactionDelegate {
    func confirmTransactionSelected(in navigationController: UINavigationController, token: Token, contract: AlphaWallet.Address, tokenId: TokenId, values: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore, transactionFunction: FunctionOrigin) {
        delegate?.confirmTransactionSelected(in: navigationController, token: token, contract: contract, tokenId: tokenId, values: values, localRefs: localRefs, server: server, session: session, keystore: keystore, transactionFunction: transactionFunction)
    }
}
