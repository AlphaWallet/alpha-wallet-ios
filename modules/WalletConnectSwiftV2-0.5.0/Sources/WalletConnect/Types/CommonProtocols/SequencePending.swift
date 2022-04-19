
import Foundation

protocol SequencePending: Codable {
    var topic: String {get}
    func isEqual(to: SequencePending) -> Bool

}
extension SequencePending where Self : Equatable {
    func isEqual (to: SequencePending) -> Bool {
        return (to as? Self).flatMap({ $0 == self }) ?? false
    }
}
