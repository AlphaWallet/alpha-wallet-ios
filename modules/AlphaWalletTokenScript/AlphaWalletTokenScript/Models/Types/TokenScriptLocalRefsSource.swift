// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public protocol TokenScriptLocalRefsSource {
    var localRefs: [AttributeId: AssetInternalValue] { get }
}
