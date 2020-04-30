// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import AlphaWallet

class TokenScriptFilterParserTests: XCTestCase {
    func testTokenizing() {
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry=123"), [.other("expiry"), .binaryOperator("="), .value("123")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry<123"), [.other("expiry"), .binaryOperator("<"), .value("123")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry>123"), [.other("expiry"), .binaryOperator(">"), .value("123")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "(expiry>123)"), [.reserved("("), .other("expiry"), .binaryOperator(">"), .value("123"), .reserved(")")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry<=123"), [.other("expiry"), .binaryOperator("<="), .value("123")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry>=123"), [.other("expiry"), .binaryOperator(">="), .value("123")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry>=hello\\29world"), [.other("expiry"), .binaryOperator(">="), .value("hello)world")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry>=hello)world"), [.other("expiry"), .binaryOperator(">="), .value("hello"), .reserved(")"), .other("world")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry>=hello>world"), [.other("expiry"), .binaryOperator(">="), .value("hello"), .binaryOperator(">"), .value("world")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "(&(birthDate=xxx)(expiry<=20200421000000))"), [.reserved("("), .reserved("&"), .reserved("("), .other("birthDate"), .binaryOperator("="), .value("xxx"), .reserved(")"), .reserved("("), .other("expiry"), .binaryOperator("<="), .value("20200421000000"), .reserved(")"), .reserved(")")])
    }

    func testTokenizingWithParenthesis() {
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "(expiry=123)"), [.reserved("("), .other("expiry"), .binaryOperator("="), .value("123"), .reserved(")")])
    }

    func testTokenizingWithInvalidEscapeSequence() {
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry>=hello\\4\\29world"), [.other("expiry"), .binaryOperator(">="), .value("hello"), .invalid("\\4"), .other(")world")])
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "expiry>=hello\\\\world"), [.other("expiry"), .binaryOperator(">="), .value("hello"), .invalid("\\\\"), .other("world")])
    }

    func testTokenizingWithImplicitValue() {
        XCTAssertEqual(TokenScriptFilterParser.Lexer().tokenize(expression: "(wallet=${ownerAddress})"), [.reserved("("), .other("wallet"), .binaryOperator("="), .value("${ownerAddress}"), .reserved(")")])
    }

    func testBasicParsing() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "expiry=123")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingWithParenthesis() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "(expiry=123)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingFilterListOne() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "&(expiry=123)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingFilterListMultipleAnd1() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "&(expiry=123)(expiry=123)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingFilterListMultipleAnd2() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "&(expiry=123)(expiry=124)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, false)
    }

    func testParsingFilterListMultipleOr1() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "|(expiry=123)(expiry=123)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingFilterListMultipleOr2() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "|(expiry=123)(expiry=124)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingFilterListMultipleOr3() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "|(expiry=124)(expiry=124)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, false)
    }

    func testParsingFilterListNot1() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "!(expiry=123)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, false)
    }

    func testParsingFilterListNot2() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "!(expiry=124)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingFilterListInvalidNot() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "!(expiry=124)(expiry=124)")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .directoryString, value: .string("123")),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, false)
    }

    func testParsingImplicitValues1() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "(wallet=${ownerAddress})")
        let wallet = AlphaWallet.Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "wallet": .init(syntax: .directoryString, value: .address(wallet)),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: TokenScriptFilterParser.Parser.valuesWithImplicitValues(values, ownerAddress: wallet, symbol: "", fungibleBalance: nil)).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingImplicitValues2() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "wallet=${ownerAddress}")
        let wallet = AlphaWallet.Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "wallet": .init(syntax: .directoryString, value: .address(wallet)),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: TokenScriptFilterParser.Parser.valuesWithImplicitValues(values, ownerAddress: wallet, symbol: "", fungibleBalance: nil)).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingImplicitValues3() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "label=prefix-${ownerAddress}-suffix")
        let label = "prefix-0x007bEe82BDd9e866b2bd114780a47f2261C684E3-suffix"
        let ownerAddress = AlphaWallet.Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "label": .init(syntax: .directoryString, value: .string(label)),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: TokenScriptFilterParser.Parser.valuesWithImplicitValues(values, ownerAddress: ownerAddress, symbol: "", fungibleBalance: nil)).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingImplicitValuesRepeat() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "label=prefix-${ownerAddress}-${ownerAddress}-suffix")
        let label = "prefix-0x007bEe82BDd9e866b2bd114780a47f2261C684E3-0x007bEe82BDd9e866b2bd114780a47f2261C684E3-suffix"
        let ownerAddress = AlphaWallet.Address(string: "0x007bEe82BDd9e866b2bd114780a47f2261C684E3")!
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "label": .init(syntax: .directoryString, value: .string(label)),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: TokenScriptFilterParser.Parser.valuesWithImplicitValues(values, ownerAddress: ownerAddress, symbol: "", fungibleBalance: nil)).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingImplicitValuesToday() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "expiry=${today}")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .generalisedTime, value: .generalisedTime(.init())),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: TokenScriptFilterParser.Parser.valuesWithImplicitValues(values, ownerAddress: .makeStormBird(), symbol: "", fungibleBalance: nil)).parse()
        XCTAssertEqual(result, true)
    }

    func testParsingGeneralisedTimePartialGreaterThan() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "expiry>2023")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .generalisedTime, value: .generalisedTime(GeneralisedTime(string: "20230405111234+0000")!)),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, false)
    }

    func testParsingGeneralisedTimePartialLessThan() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "expiry<2023")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .generalisedTime, value: .generalisedTime(GeneralisedTime(string: "20230405111234+0000")!)),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, false)
    }

    func testParsingGeneralisedTimePartialEqual() {
        let tokens = TokenScriptFilterParser.Lexer().tokenize(expression: "expiry=2023")
        let values: [AttributeId: AssetAttributeSyntaxValue] = [
            "expiry": .init(syntax: .generalisedTime, value: .generalisedTime(GeneralisedTime(string: "20230405111234+0000")!)),
        ]
        let result = TokenScriptFilterParser.Parser(tokens: tokens, values: values).parse()
        XCTAssertEqual(result, true)
    }
}
