// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

public struct TokenScriptCard {
    public let name: String
    public let eventOrigin: EventOrigin
    public let view: (html: String, urlFragment: String?, style: String)
    public let itemView: (html: String, urlFragment: String?, style: String)
    public let isBase: Bool

    public init(name: String, eventOrigin: EventOrigin, view: (html: String, urlFragment: String?, style: String), itemView: (html: String, urlFragment: String?, style: String), isBase: Bool) {
        self.name = name
        self.eventOrigin = eventOrigin
        self.view = view
        self.itemView = itemView
        self.isBase = isBase
    }
}
