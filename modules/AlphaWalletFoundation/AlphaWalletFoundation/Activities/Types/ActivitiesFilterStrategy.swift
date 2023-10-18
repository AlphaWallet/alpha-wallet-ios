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
extension Token {
    public var activitiesFilterStrategy: ActivitiesFilterStrategy {
        switch self.type {
        case .nativeCryptocurrency:
            return .nativeCryptocurrency(primaryKey: primaryKey)
        case .erc20, .erc875:
            return .contract(contract: contractAddress)
        case .erc721ForTickets, .erc721, .erc1155:
            return .operationTypes(operationTypes: [], contract: contractAddress)
        }
    }
}

extension ActivitiesFilterStrategy {
    enum functional {}
}

fileprivate extension ActivitiesFilterStrategy.functional {
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
