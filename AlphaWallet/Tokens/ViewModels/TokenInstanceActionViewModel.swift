// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TokenInstanceActionViewModel {
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var actions: [TokenInstanceAction] {
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, assetDefinitionStore: assetDefinitionStore)
        return xmlHandler.actions
    }
}
