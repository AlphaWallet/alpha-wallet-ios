// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import Combine

public final class ReportUsersActiveChains: Service {
    private let serversProvider: ServersProvidable
    private var cancelable = Set<AnyCancellable>()

    public init(serversProvider: ServersProvidable) {
        self.serversProvider = serversProvider
    }

    public func perform() {
        //NOTE: make 2 sec delay to avoid load on launch
        serversProvider.enabledServersPublisher
            .delay(for: .seconds(2), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { crashlytics.track(enabledServers: Array($0)) }
            .store(in: &cancelable)
    }
}
