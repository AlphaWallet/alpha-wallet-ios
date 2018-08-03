// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Result

/// This is a workaround to workaround a Swift bug so we can use Result.Result in a .swift file when Alamofire is also used in that file
struct ResultResult<T, Error : Swift.Error> {
    typealias t = Result<T, Error>
}