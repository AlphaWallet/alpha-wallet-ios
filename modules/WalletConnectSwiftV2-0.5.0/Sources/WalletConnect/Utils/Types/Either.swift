enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

extension Either {

    init(_ left: Left) {
        self = .left(left)
    }

    init(_ right: Right) {
        self = .right(right)
    }

    var left: Left? {
        guard case let .left(left) = self else { return nil }
        return left
    }

    var right: Right? {
        guard case let .right(right) = self else { return nil }
        return right
    }
}

extension Either: Equatable where Left: Equatable, Right: Equatable {

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.left(lhs), .left(rhs)):
            return lhs == rhs
        case let (.right(lhs), .right(rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}

extension Either: Codable where Left: Codable, Right: Codable {

    init(from decoder: Decoder) throws {
        if let left = try? Left(from: decoder) {
            self.init(left)
        } else if let right = try? Right(from: decoder) {
            self.init(right)
        } else {
            let errorDescription = "Data couldn't be decoded into either of the underlying types."
            let errorContext = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: errorDescription)
            throw DecodingError.typeMismatch(Self.self, errorContext)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .left(left):
            try left.encode(to: encoder)
        case let .right(right):
            try right.encode(to: encoder)
        }
    }
}
