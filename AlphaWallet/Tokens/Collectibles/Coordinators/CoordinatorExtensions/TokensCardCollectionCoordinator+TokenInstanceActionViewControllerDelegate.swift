//
//  TokensCardCollectionCoordinator+TokenInstanceActionViewControllerDelegate.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import Foundation

extension TokensCardCollectionCoordinator: TokenInstanceActionViewControllerDelegate {
    func didPressViewRedemptionInfo(in viewController: TokenInstanceActionViewController) {
        //no-op, remove it later
    }

    func shouldCloseFlow(inViewController viewController: TokenInstanceActionViewController) {
        viewController.navigationController?.popViewController(animated: true)
    }

    func confirmTransactionSelected(in viewController: TokenInstanceActionViewController, tokenObject: TokenObject, contract: AlphaWallet.Address, tokenId: TokenId, values: [AttributeId: AssetInternalValue], localRefs: [AttributeId: AssetInternalValue], server: RPCServer, session: WalletSession, keystore: Keystore, transactionFunction: FunctionOrigin) {
        /*
        switch transactionFunction.makeUnConfirmedTransaction(withTokenObject: tokenObject, tokenId: tokenId, attributeAndValues: values, localRefs: localRefs, server: server, session: session) {
        case .success((let transaction, let functionCallMetaData)):
            let coordinator = TransactionConfirmationCoordinator(presentingViewController: navigationController, session: session, transaction: transaction, configuration: .tokenScriptTransaction(confirmType: .signThenSend, contract: contract, keystore: keystore, functionCallMetaData: functionCallMetaData, ethPrice: ethPrice), analyticsCoordinator: analyticsCoordinator)
            coordinator.delegate = self
            addCoordinator(coordinator)
            coordinator.start(fromSource: .tokenScript)
        case .failure:
            //TODO throw an error
            break
        }
         */
    }

}
