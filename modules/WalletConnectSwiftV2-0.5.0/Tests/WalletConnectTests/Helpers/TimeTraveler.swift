import Foundation

final class TimeTraveler {
    
    private(set) var referenceDate = Date()
    
    func generateDate() -> Date {
        return referenceDate
    }
    
    func travel(by timeInterval: TimeInterval) {
        referenceDate = referenceDate.addingTimeInterval(timeInterval)
    }
}
