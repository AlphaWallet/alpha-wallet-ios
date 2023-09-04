// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

public struct Filename: Hashable, Codable {
    let value: String

    //For official TokenScript XML files sourced from URLs, we use the hash as the filename
    static func convertFromOfficialXmlHash(_ hash: FileContentsHash) -> Self {
        return Self(value: hash.value)
    }
}
