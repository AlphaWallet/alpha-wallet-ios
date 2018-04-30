// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct BackupViewModel {

    let config: Config

    init(
        config: Config = Config()
    ) {
        self.config = config
    }

    var headlineText: String {
        return R.string.localizable.exportNoBackupLabelTitle(config.server.name)
    }
}
