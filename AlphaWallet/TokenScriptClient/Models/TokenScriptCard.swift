// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

struct TokenScriptCard {
    let name: String
    let eventOrigin: EventOrigin
    let view: (html: String, style: String)
    let itemView: (html: String, style: String)
    let isBase: Bool
}
