// Copyright © 2023 Stormbird PTE. LTD.

import Foundation

struct FileContentsHash: Hashable, Codable {
    let value: String

    //For official TokenScript XML files sourced from URLs, we use the hash as the filename
    static func convertFromOfficialXmlFilename(_ filename: Filename) -> Self {
        return Self(value: filename.value)
    }
}
