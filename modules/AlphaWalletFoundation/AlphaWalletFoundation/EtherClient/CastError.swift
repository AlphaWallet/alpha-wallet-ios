// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public struct CastError<ExpectedType>: Error {
    let actualValue: Any
    let expectedType: ExpectedType.Type
    
    public init(actualValue: Any, expectedType: ExpectedType.Type) {
        self.actualValue = actualValue
        self.expectedType = expectedType
    }
}
