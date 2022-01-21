// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum TransactionFetchingState: Int {
    case initial = 0
    case failed
    case done

    init(int: Int) {
        self = TransactionFetchingState(rawValue: int) ?? .initial
    }
}

class TransactionsTracker {
    private var fetchingStateKey: String {
        return "transactions.fetchingState-\(sessionID)"
    }

    let sessionID: String
    let defaults: UserDefaults

    var fetchingState: TransactionFetchingState {
        get { return TransactionFetchingState(int: defaults.integer(forKey: fetchingStateKey)) }
        set { return defaults.set(newValue.rawValue, forKey: fetchingStateKey) }
    }

    init(
        sessionID: String,
        defaults: UserDefaults = .standardOrForTests
    ) {
        self.sessionID = sessionID
        self.defaults = defaults
    }

    static func resetFetchingState(account: Wallet, config: Config, fetchingState: TransactionFetchingState = .initial) {
        for each in config.enabledServers {
            let sessionID = WalletSession.functional.sessionID(account: account, server: each)
            TransactionsTracker(sessionID: sessionID).fetchingState = fetchingState
        }
    }
}
