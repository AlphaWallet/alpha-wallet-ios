//
//  StringValidator.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 2/12/21.
//

import Foundation

typealias StringValidatorResult = Result<Void, StringValidator.Errors>

class StringValidator {
    enum Errors: Error {
        case list([StringValidator.Rule])
    }

    enum Rule {
        case lengthLessThan(Int)
        case lengthLessThanOrEqualTo(Int)
        case lengthMoreThan(Int)
        case lengthMoreThanOrEqualTo(Int)
        case doesNotContain(CharacterSet)
        case canOnlyContain(CharacterSet)

        func validate(_ inputString: String) -> Bool {
            switch self {
            case .lengthLessThan(let length):
                return inputString.count < length
            case .lengthLessThanOrEqualTo(let length):
                return inputString.count <= length
            case .lengthMoreThan(let length):
                return inputString.count > length
            case .lengthMoreThanOrEqualTo(let length):
                return inputString.count >= length
            case .doesNotContain(let set):
                return inputString.rangeOfCharacter(from: set) == nil
            case .canOnlyContain(let set):
                return inputString.rangeOfCharacter(from: set.inverted) == nil
            }
        }
    }

    private var rules: [StringValidator.Rule]

    init() {
        self.rules = []
    }

    init(rules: [StringValidator.Rule]) {
        self.rules = rules
    }

    func validate(string inputString: String) -> StringValidatorResult {
        let errors = rules.compactMap {
            $0.validate(inputString) ? nil : $0
        }
        if errors.isEmpty {
            return .success(())
        }
        return .failure(.list(errors))
    }

    func containsIllegalCharacters(string inputString: String) -> Bool {
        guard case let Result.failure(StringValidator.Errors.list(errors)) = validate(string: inputString) else { return false }
        let filteredErrors: [StringValidator.Rule] = errors.compactMap { error in
            switch error {
            case StringValidator.Rule.lengthLessThan, StringValidator.Rule.lengthLessThanOrEqualTo, StringValidator.Rule.lengthMoreThan, StringValidator.Rule.lengthMoreThanOrEqualTo:
                return nil
            default:
                return error
            }
        }
        return !filteredErrors.isEmpty
    }
}

