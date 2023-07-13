// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletLogger
import Foundation

public class TickerIdsMatchLog: Service {
    public init() {}
    public func perform() {
        if Features.current.isAvailable(.isLoggingEnabledForTickerMatches) {
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
                infoLog("Ticker ID positive matching counts: \(TickerIdFilter.matchCounts)")
            }
        }
    }
}