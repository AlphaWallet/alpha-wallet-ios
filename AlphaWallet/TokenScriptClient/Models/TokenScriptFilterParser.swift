// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt

// swiftlint:disable type_body_length
struct TokenScriptFilterParser {
    enum Operator: String {
        case equal = "="
        case lessThan = "<"
        case greaterThan = ">"
        case lessThanOrEqual = "<="
        case greaterThanOrEqual = ">="

// swiftlint:disable function_body_length
        func isTrueFor(attributeValue: AssetInternalValue, value: String) -> Bool {
            switch attributeValue {
            case .address(let address):
                switch self {
                case .equal:
                    return address.eip55String.lowercased() == value.lowercased()
                case .lessThan:
                    return false
                case .greaterThan:
                    return false
                case .lessThanOrEqual:
                    return false
                case .greaterThanOrEqual:
                    return false
                }
            case .bool(let bool):
                switch self {
                case .equal:
                    return (bool ? "TRUE": "FALSE") == value
                case .lessThan:
                    return false
                case .greaterThan:
                    return false
                case .lessThanOrEqual:
                    return false
                case .greaterThanOrEqual:
                    return false
                }
            case .string(let string):
                switch self {
                case .equal:
                    return string == value
                case .lessThan:
                    return string < value
                case .greaterThan:
                    return string > value
                case .lessThanOrEqual:
                    return string <= value
                case .greaterThanOrEqual:
                    return string >= value
                }
            case .bytes(let bytes):
                guard let a = BigUInt(bytes.hexEncoded, radix: 16), let b = BigUInt(value, radix: 16) else { return false }
                switch self {
                case .equal:
                    return a == b
                case .lessThan:
                    return a < b
                case .greaterThan:
                    return a > b
                case .lessThanOrEqual:
                    return a <= b
                case .greaterThanOrEqual:
                    return a >= b
                }
            case .int(let int):
                guard let rhs = BigInt(value) else { return false }
                switch self {
                case .equal:
                    return int == rhs
                case .lessThan:
                    return int < rhs
                case .greaterThan:
                    return int > rhs
                case .lessThanOrEqual:
                    return int <= rhs
                case .greaterThanOrEqual:
                    return int >= rhs
                }
            case .uint(let uint):
                //Must check for -ve. Will crash if used to init BigUInt
                if value.trimmed.hasPrefix("-"), let rhs = BigInt(value) {
                    switch self {
                    case .equal:
                        return uint == rhs
                    case .lessThan:
                        return uint < rhs
                    case .greaterThan:
                        return uint > rhs
                    case .lessThanOrEqual:
                        return uint <= rhs
                    case .greaterThanOrEqual:
                        return uint >= rhs
                    }
                } else if let rhs = BigUInt(value) {
                    switch self {
                    case .equal:
                        return uint == rhs
                    case .lessThan:
                        return uint < rhs
                    case .greaterThan:
                        return uint > rhs
                    case .lessThanOrEqual:
                        return uint <= rhs
                    case .greaterThanOrEqual:
                        return uint >= rhs
                    }
                } else {
                    return false
                }
            case .generalisedTime(let generalisedTime):
                let generalisedTimeString = generalisedTime.formatAsGeneralisedTime
                //This is consistent with how "expiry<${today} would work
                let truncatedGeneralisedTime = generalisedTimeString.substring(to: value.count)
                switch self {
                case .equal:
                    return truncatedGeneralisedTime == value
                case .lessThan:
                    return truncatedGeneralisedTime < value
                case .greaterThan:
                    return truncatedGeneralisedTime > value
                case .lessThanOrEqual:
                    return truncatedGeneralisedTime <= value
                case .greaterThanOrEqual:
                    return truncatedGeneralisedTime >= value
                }
            case .subscribable, .openSeaNonFungibleTraits:
                return false
            }
        }
// swiftlint:enable function_body_length
    }

    struct Lexer {
        //Some terminology from subset of https://tools.ietf.org/html/rfc2254. Look under "String Search Filter Definition"
        enum Token: Equatable {
            case reserved(String)
            case value(String)
            case binaryOperator(String)
            case other(String)
            case invalid(String)

            var otherValue: String? {
                switch self {
                case .value, .invalid, .binaryOperator, .reserved:
                    return nil
                case .other(let string):
                    return string
                }
            }
            var valueValue: String? {
                switch self {
                case .other, .invalid, .binaryOperator, .reserved:
                    return nil
                case .value(let value):
                    return value
                }
            }
            var binaryOperatorValue: String? {
                switch self {
                case .value, .invalid, .other, .reserved:
                    return nil
                case .binaryOperator(let string):
                    return string
                }
            }
        }

        private static let reservedTokens = ["=", "<", ">", "<=", ">=", "(", ")", "&", "|", "!"]
        private let reservedTokens = Lexer.reservedTokens
        private let binaryOperators = ["=", "<", ">", "<=", ">="]
        private let escape = Character("\\")
        //Generating it rather than manually writing it, introducing errors
        private let reservedCharacters: [String] = {
            let all = Lexer.reservedTokens.map { each -> [String] in
                if each.count == 2 {
                    return [each[0], each[1]]
                } else if each.count == 1 {
                    return [each[0]]
                } else {
                    return []
                }
            }
            return all.flatMap { $0 }
        }()

        func tokenize(expression: String) -> [Token] {
            var result: [Token] = []
            var buffer: [Character] = []
            var escapeBuffer: [Character]? = nil
            var wasPreviousEscapedCharacter = false
            for (_, c) in expression.enumerated() {
                let previous = buffer.last.flatMap { String($0) }
                if c == escape && escapeBuffer == nil {
                    //start new escape
                    escapeBuffer = .init()
                    continue
                } else if c == escape, let eb = escapeBuffer {
                    if escapeBuffer.isEmpty {
                        //Invalid escape sequence with double backward slash (\\)
                        if !buffer.isEmpty {
                            result = append(buffer, toTokens: result)
                            buffer = .init()
                        }
                        result.append(.invalid(String("\\\\")))
                        escapeBuffer = nil
                        continue
                    } else {
                        //Invalid. Start another escape sequence
                        if !buffer.isEmpty {
                            result = append(buffer, toTokens: result)
                            buffer = .init()
                        }
                        result.append(.invalid(String("\\\(String(eb))")))
                        escapeBuffer = .init()
                        continue
                    }
                } else if var eb = escapeBuffer {
                    if eb.isEmpty {
                        escapeBuffer?.append(c)
                        continue
                    } else if eb.count == 1 {
                        //1 — we have 1 character of the escape sequence already
                        //Finished escaping
                        eb.append(c)
                        convertHexToCharacter(String(eb)).flatMap { buffer.append($0) }
                        escapeBuffer = nil
                        wasPreviousEscapedCharacter = true
                        continue
                    } else {
                        //no-op
                    }
                }

                defer { wasPreviousEscapedCharacter = false }

                //reserved character
                if reservedCharacters.contains(String(c)) {
                    if let previous = previous, !reservedCharacters.contains(previous) {
                        //start reserve
                        if !buffer.isEmpty {
                            result = append(buffer, toTokens: result)
                        }
                        buffer = [c]
                    } else if reservedTokens.contains("\(String(buffer))\(c)") {
                        //more for this reserved token
                        buffer.append(c)
                    } else {
                        //encounters stop, so assume end previous, start new token, saving previous as a token
                        if !buffer.isEmpty {
                            result = append(buffer, toTokens: result)
                        }
                        buffer = [c]
                    }
                    //not reserved, reserved now
                } else if let previous = previous, reservedCharacters.contains(previous), !wasPreviousEscapedCharacter {
                    //previous last char was a stop, but not anymore, so save token and start new
                    let token = String(buffer)
                    if binaryOperators.contains(token) {
                        result.append(.binaryOperator(String(buffer)))
                    } else {
                        result.append(.reserved(String(buffer)))
                    }
                    buffer = [c]
                } else {
                    //continue token
                    buffer.append(c)
                }
            }
            if !buffer.isEmpty {
                if let previousToken = result.last {
                    switch previousToken {
                    case .binaryOperator:
                        result.append(.value(String(buffer)))
                    case .reserved, .value, .other, .invalid:
                        if reservedTokens.contains(String(buffer)) {
                            result.append(.reserved(String(buffer)))
                        } else {
                            result.append(.other(String(buffer)))
                        }
                    }
                } else {
                    if reservedTokens.contains(String(buffer)) {
                        result.append(.reserved(String(buffer)))
                    } else {
                        result.append(.other(String(buffer)))
                    }
                }
            }
            return result
        }

        private func convertHexToCharacter(_ hex: String) -> Character? {
            let code = Int(strtoul(hex, nil, 16))
            return UnicodeScalar(code).flatMap { Character($0) }
        }

        private func append(_ characters: [Character], toTokens originalTokens: [Token]) -> [Token] {
            var result = originalTokens
            let token = String(characters)
            if let previousToken = originalTokens.last {
                switch previousToken {
                case .binaryOperator:
                    result.append(.value(token))
                case .reserved, .value, .other, .invalid:
                    if reservedTokens.contains(token) {
                        result.append(.reserved(token))
                    } else {
                        result.append(.other(token))
                    }
                }
            } else {
                if reservedTokens.contains(token) {
                    result.append(.reserved(token))
                } else {
                    result.append(.other(token))
                }
            }
            return result
        }
    }

    //Adopts some terminology like filter, filtercomp, etc from https://tools.ietf.org/html/rfc2254
    class Parser {
        private let values: [AttributeId: AssetAttributeSyntaxValue]
        private var tokens: [Lexer.Token]

        static func valuesWithImplicitValues(_ values: [AttributeId: AssetAttributeSyntaxValue], ownerAddress: AlphaWallet.Address, symbol: String, fungibleBalance: BigInt?) -> [AttributeId: AssetAttributeSyntaxValue] {
            let todayString = GeneralisedTime().formatAsGeneralisedTime.substring(to: 8)
            var implicitValues: [AttributeId: AssetAttributeSyntaxValue] = [
                "symbol": .init(syntax: .directoryString, value: .string(symbol)),
                "today": .init(syntax: .directoryString, value: .string(todayString)),
                "ownerAddress": .init(syntax: .directoryString, value: .address(ownerAddress)),
            ]
            if let fungibleBalance = fungibleBalance {
                implicitValues["balance"] = .init(syntax: .integer, value: .int(fungibleBalance))
            }
            return values.merging(implicitValues) { (_, new) in new }
        }

        init(tokens: [Lexer.Token], values: [AttributeId: AssetAttributeSyntaxValue]) {
            self.tokens = tokens
            self.values = values
        }

        private func isExpected(token expectedToken: Lexer.Token) -> Bool {
            let token = tokens.removeFirst()
            return token == expectedToken
        }

        private func lookAhead() -> Lexer.Token? {
            tokens.first
        }

        func parse() -> Bool {
            let result: Bool?
            if lookAhead() == .reserved("(") {
                result = parseFilter()
            } else {
                result = parseFilterComp()
            }
            guard tokens.isEmpty else { return false }
            return result ?? false
        }

        private func parseFilter() -> Bool? {
            guard isExpected(token: .reserved("(")) else { return nil }
            let result = parseFilterComp()
            guard isExpected(token: .reserved(")")) else { return nil }
            return result
        }

        private func parseFilterComp() -> Bool? {
            switch lookAhead() {
            case .none:
                return nil
            case .some(.reserved("&")):
                return parseAnd()
            case .some(.reserved("|")):
                return parseOr()
            case .some(.reserved("!")):
                return parseNot()
            case .some:
                return parseItem()
            }
        }

        private func parseAnd() -> Bool? {
            guard isExpected(token: .reserved("&")) else { return nil }
            guard let resultsOfOptionals = parseFilterList() else { return nil }
            let results = resultsOfOptionals.compactMap { $0 }
            if results.count == resultsOfOptionals.count {
                return results.allSatisfy { $0 }
            } else {
                return false
            }
        }

        private func parseOr() -> Bool? {
            guard isExpected(token: .reserved("|")) else { return nil }
            guard let resultsOfOptionals = parseFilterList() else { return nil }
            let results = resultsOfOptionals.compactMap { $0 }
            if results.count == resultsOfOptionals.count {
                return results.contains { $0 }
            } else {
                return false
            }
        }

        private func parseNot() -> Bool? {
            guard isExpected(token: .reserved("!")) else { return nil }
            guard let result = parseFilter() else { return nil }
            return !result
        }

        private func parseFilterList() -> [Bool?]? {
            var results: [Bool?] = .init()
            repeat {
                if lookAhead() == .reserved("(") {
                    if let result = parseFilter() {
                        results.append(result)
                    } else {
                        results.append(nil)
                        break
                    }
                } else {
                    break
                }
            } while true

            if results.isEmpty {
                return nil
            } else {
                return results
            }
        }

        private func parseItem() -> Bool? {
            parseSimple()
        }

        private func parseSimple() -> Bool? {
            guard let attribute = tokens.removeFirst().otherValue else { return false }
            guard let attributeValue = values[attribute]?.value.resolvedValue else { return false }
            guard let op = tokens.removeFirst().binaryOperatorValue.flatMap({ Operator(rawValue: $0) }) else { return false }
            guard let value = tokens.removeFirst().valueValue else { return false }
            guard let interpolatedValue = interpolate(value: value) else { return nil }
            return op.isTrueFor(attributeValue: attributeValue, value: interpolatedValue)
        }

        //TODO replace the very dumb regex for now. And also recursively interpolates (not good). Should involve parser
        private func interpolate(value: String) -> String? {
            var value = value
            repeat {
                guard let regex = try? NSRegularExpression(pattern: "\\$\\{(?<attribute>[a-zA-Z][a-zA-Z0-9]*)\\}", options: []) else { return nil }
                let range = NSRange(value.startIndex ..< value.endIndex, in: value)
                let matches = regex.matches(in: value, options: [], range: range)
                guard matches.count >= 1 else { return value }
                guard let attributeRange = Range(matches[0].range(withName: "attribute"), in: value) else { return value }
                var rangeIncludingDelimiters = matches[0].range(withName: "attribute")
                rangeIncludingDelimiters = NSRange(location: rangeIncludingDelimiters.lowerBound - 2, length: rangeIncludingDelimiters.length + 3)
                guard let attributeReplacementRange = Range(rangeIncludingDelimiters, in: value) else { return value }
                let attribute = String(value[attributeRange])

                guard let attributeValue = values[attribute]?.value.resolvedValue else { return nil }
                let attributeValueString: String
                switch attributeValue {
                case .address(let address):
                    attributeValueString = address.eip55String
                case .bool(let bool):
                    attributeValueString = bool ? "TRUE": "FALSE"
                case .string(let string):
                    attributeValueString = string
                case .bytes(let bytes):
                    attributeValueString = bytes.hexEncoded
                case .int(let int):
                    attributeValueString = String(int)
                case .uint(let uint):
                    attributeValueString = String(uint)
                case .generalisedTime(let generalisedTime):
                    attributeValueString = generalisedTime.formatAsGeneralisedTime
                case .subscribable, .openSeaNonFungibleTraits:
                    return nil
                }

                value.replaceSubrange(attributeReplacementRange, with: attributeValueString)
            } while true
            return value
        }
    }

    let expression: String

    func parse(withValues values: [AttributeId: AssetAttributeSyntaxValue], ownerAddress: AlphaWallet.Address, symbol: String, fungibleBalance: BigInt?) -> Bool {
        let tokens = Lexer().tokenize(expression: expression)
        let values = Parser.valuesWithImplicitValues(values, ownerAddress: ownerAddress, symbol: symbol, fungibleBalance: fungibleBalance)
        return Parser(tokens: tokens, values: values).parse()
    }
}
// swiftlint:enable type_body_length

fileprivate extension String {
	subscript(i: Int) -> String {
		self[i ..< i + 1]
	}

	subscript(r: Range<Int>) -> String {
		let range = Range(uncheckedBounds: (lower: max(0, min(count, r.lowerBound)), upper: min(count, max(0, r.upperBound))))
		let start = index(startIndex, offsetBy: range.lowerBound)
		let end = index(start, offsetBy: range.upperBound - range.lowerBound)
		return String(self[start ..< end])
	}
}
