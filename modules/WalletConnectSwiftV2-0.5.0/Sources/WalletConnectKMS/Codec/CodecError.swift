//

import Foundation

enum CodecError: Error {
    case stringToDataFailed(String)
    case dataToStringFailed(Data)
}
