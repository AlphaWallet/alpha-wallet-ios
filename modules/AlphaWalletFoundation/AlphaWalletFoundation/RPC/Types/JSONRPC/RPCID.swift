import Foundation

public typealias RpcId = Either<String, Int64>

public protocol IdentifierGenerator {
    func next() -> RpcId
}

struct IntIdentifierGenerator: IdentifierGenerator {
    private static var index: Int64 = 0
    func next() -> RpcId {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000) * 1000
        let random = Int64.random(in: 0..<1000)
        return RpcId(timestamp + random)
    }
}

extension RpcId {

    public var timestamp: Date {
        guard let id = self.right else { return .distantPast }
        let interval = TimeInterval(id / 1000 / 1000)
        return Date(timeIntervalSince1970: interval)
    }
}
