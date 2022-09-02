// Copyright DApps Platform Inc. All rights reserved.

import Foundation

public struct DAppRequester {
    public let title: String?
    public let url: URL?

    public init(title: String?, url: URL?) {
        self.title = title
        self.url = url
    }
}
