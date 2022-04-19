
import Foundation

protocol SequenceSettled: Codable {
    var topic: String {get}
    func isEqual(to: SequenceSettled) -> Bool

}
extension SequenceSettled where Self : Equatable {
    func isEqual (to: SequenceSettled) -> Bool {
        return (to as? Self).flatMap({ $0 == self }) ?? false
    }
}
