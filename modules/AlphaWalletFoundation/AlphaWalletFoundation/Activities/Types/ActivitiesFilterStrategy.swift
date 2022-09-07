//
//  ActivitiesFilterStrategy.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2022.
//

import Foundation

public enum ActivitiesFilterStrategy {
    case none
    case nativeCryptocurrency(primaryKey: String)
    case contract(contract: AlphaWallet.Address)
    case operationTypes(operationTypes: [OperationType], contract: AlphaWallet.Address)

    var predicate: NSPredicate {
        switch self {
        case .nativeCryptocurrency:
            return ActivitiesFilterStrategy.functional.predicateForNativeCryptocurrencyTransactions()
        case .contract(let contract):
            return ActivitiesFilterStrategy.functional.predicateForERC20TokenTransactions(contract: contract)
        case .operationTypes(let operationTypes, let contract):
            return ActivitiesFilterStrategy.functional.predicateForTransactionsForCustomOperations(operationTypes: operationTypes, contract: contract)
        case .none:
            return NSPredicate(format: "")
        }
    }
}

public extension TransactionState {
    static func predicate(for value: TransactionState, field: String = "internalState") -> NSPredicate {
        NSPredicate(format: "\(field) = \(value.rawValue)")
    }
}

extension TransactionType {
    public var activitiesFilterStrategy: ActivitiesFilterStrategy {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return .nativeCryptocurrency(primaryKey: token.primaryKey)
        case .erc20Token(let tokenObject, _, _):
            return .contract(contract: tokenObject.contractAddress)
        case .erc875Token(let token, _), .erc875TokenOrder(let token, _):
            return .contract(contract: token.contractAddress)
        case .erc721Token(let token, _), .erc721ForTicketToken(let token, _), .erc1155Token(let token, _, _):
            return .operationTypes(operationTypes: [], contract: token.contractAddress)
        case .dapp, .claimPaidErc875MagicLink, .tokenScript, .prebuilt:
            return .none
        }
    }
}

fileprivate extension ActivitiesFilterStrategy {
    enum functional {}
}

extension ActivitiesFilterStrategy.functional {
    static func predicateForNativeCryptocurrencyTransactions() -> NSPredicate {
        let completed = TransactionState.predicate(for: .completed)
        let pending = TransactionState.predicate(for: .pending)
        let isInCompletedOrPandingState = NSCompoundPredicate(orPredicateWithSubpredicates: [completed, pending])
        let valueNonEmpty = NSPredicate(format: "value != '' AND value != '0'")
        let hasZeroOperations = NSPredicate(format: "localizedOperations.@count == 0")

        return NSCompoundPredicate(andPredicateWithSubpredicates: [isInCompletedOrPandingState, hasZeroOperations, valueNonEmpty])
    }

    static func predicateForERC20TokenTransactions(contract: AlphaWallet.Address) -> NSPredicate {
        //TODO shouldn't we support other operation types?
        return predicateForTransactionsForCustomOperations(operationTypes: [.erc20TokenTransfer, .erc20TokenApprove], contract: contract)
    }

    static func predicateForTransactionsForCustomOperations(operationTypes: [OperationType], contract: AlphaWallet.Address) -> NSPredicate {
        let completed = TransactionState.predicate(for: .completed)
        let pending = TransactionState.predicate(for: .pending)
        let isInCompletedOrPandingState = NSCompoundPredicate(orPredicateWithSubpredicates: [completed, pending])

        let isMatchingSomeOperationContract = NSPredicate(format: "ANY localizedOperations.contract = '\(contract.eip55String)'")

        if operationTypes.isEmpty {
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                isInCompletedOrPandingState,
                isMatchingSomeOperationContract
            ])
        } else {
            let hasAnyValidOperationTypes = NSPredicate(format: "ANY localizedOperations.type IN %@", operationTypes.map { $0.rawValue })
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                isInCompletedOrPandingState,
                isMatchingSomeOperationContract,
                hasAnyValidOperationTypes
            ])
        }
    }
}
