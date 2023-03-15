// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct CastError<ExpectedType>: LocalizedError {
    let actualValue: Any
    let expectedType: ExpectedType.Type

    public init(actualValue: Any, expectedType: ExpectedType.Type) {
        self.actualValue = actualValue
        self.expectedType = expectedType
    }

    public var errorDescription: String? {
        return "Decode failure: Unable to decode value of \(actualValue) to expected type \(String(describing: expectedType))"
    }
}
