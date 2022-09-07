// Copyright SIX DAY LLC. All rights reserved.

import Foundation

extension Bundle {
    public var versionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    public var buildNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }

    public var buildNumberInt: Int {
        return Int(Bundle.main.buildNumber ?? "-1") ?? -1
    }

    public var fullVersion: String {
        let versionNumber = Bundle.main.versionNumber ?? ""
        let buildNumber = Bundle.main.buildNumber ?? ""
        return "\(versionNumber) (\(buildNumber))"
    }
}

public var isDebug: Bool {
    #if DEBUG
        return true
    #else
        return false
    #endif
}
