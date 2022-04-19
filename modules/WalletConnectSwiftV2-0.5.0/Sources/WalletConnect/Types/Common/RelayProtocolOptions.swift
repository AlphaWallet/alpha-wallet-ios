
import Foundation

struct RelayProtocolOptions: Codable, Equatable {
    let `protocol`: String
    let params: [String]?
}

extension RelayProtocolOptions {
    
    func asPercentEncodedString() -> String {
        guard let string = try? self.json().addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return ""
        }
        return string
    }
}
