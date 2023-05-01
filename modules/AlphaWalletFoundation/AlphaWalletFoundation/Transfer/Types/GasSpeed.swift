// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum GasSpeed: Int, CaseIterable {
    case slow
    case standard
    case fast
    case rapid
    case custom

    public static var sortedThirdPartyFastestFirst: [GasSpeed] {
        //We intentionally do not include `.standard`
        [.rapid, .fast, .slow]
    }

    static var sortedEip1559FastestFirst: [GasSpeed] {
        [.rapid, .fast, .standard, .slow]
    }
}

public enum TransactionConfiguratorError: LocalizedError {
    case impossibleToBuildConfiguration

    public var errorDescription: String? {
        return "Impossible To Build Configuration"
    }
}

public enum EstimatedValue<T> {
    case estimated(T)
    case defined(T)

    public var value: T {
        switch self {
        case .defined(let v): return v
        case .estimated(let v): return v
        }
    }

    public init<T2>(value: T, mapping: EstimatedValue<T2>) {
        switch mapping {
        case .defined:
            self = .defined(value)
        case .estimated:
            self = .estimated(value)
        }
    }

    public func mapValue<T2>(_ block: (T) -> T2) -> EstimatedValue<T2> {
        switch self {
        case .estimated(let t): return .estimated(block(t))
        case .defined(let t): return .defined(block(t))
        }
    }
}

public protocol Warning {}

extension Warning {
    public var localizedDescription: String {
        //Bit of a tight coupling here, checking for a child type, but it makes implementation of `LocalizedWarning.warningDescription` mirror that of `LocalizedError.errorDescription`
        if let localizedWarning = self as? LocalizedWarning {
            return localizedWarning.warningDescription ?? "\(self)"
        } else {
            return "\(self)"
        }
    }
}

public protocol LocalizedWarning: Warning {
    var warningDescription: String? { get }
}

public struct FillableValue<T> {
    public let value: T
    public let warnings: [Warning]
    public let errors: [Error]

    public init(value: T, warnings: [Warning], errors: [Error]) {
        self.value = value
        self.warnings = warnings
        self.errors = errors
    }

    public func mapValue<T2>(_ block: (T) -> T2) -> FillableValue<T2> {
        return .init(value: block(value), warnings: warnings, errors: errors)
    }
}
