// Copyright SIX DAY LLC. All rights reserved.

import Foundation

//public enum TransactionFetchingState: Int {
//    case initial = 0
//    case failed
//    case done
//
//    public init(int: Int) {
//        self = TransactionFetchingState(rawValue: int) ?? .initial
//    }
//}
//
//public final class TransactionsTracker {
//    private var fetchingStateKey: String {
//        return "transactions.fetchingState-\(sessionID)"
//    }
//
//    public let sessionID: String
//    public let defaults: UserDefaults
//
//    public var fetchingState: TransactionFetchingState {
//        get { return TransactionFetchingState(int: defaults.integer(forKey: fetchingStateKey)) }
//        set { return defaults.set(newValue.rawValue, forKey: fetchingStateKey) }
//    }
//
//    public init(sessionID: String,
//                defaults: UserDefaults = .standardOrForTests) {
//
//        self.sessionID = sessionID
//        self.defaults = defaults
//    }
//
//    public static func resetFetchingState(account: Wallet,
//                                          serversProvider: ServersProvidable,
//                                          fetchingState: TransactionFetchingState = .initial) {
//
//        for each in serversProvider.enabledServers {
//            let sessionID = WalletSession.functional.sessionID(account: account, server: each)
//            TransactionsTracker(sessionID: sessionID).fetchingState = fetchingState
//        }
//    }
//}
