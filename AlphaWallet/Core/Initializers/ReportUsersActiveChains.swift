// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import Combine

final class ReportUsersActiveChains: Initializer {
    private let config: Config
    private var cancelable = Set<AnyCancellable>()

    init(config: Config) {
        self.config = config
    }

    func perform() {
        //NOTE: make 2 sec delay to avoid load on launch
        Just(config.enabledServers).merge(with: config.enabledServersPublisher)
            .delay(for: .seconds(2), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { servers in
                crashlytics?.track(enabledServers: servers)
            }.store(in: &cancelable)
    }
}
