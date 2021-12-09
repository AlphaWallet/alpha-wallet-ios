//
//  StringValidatorTestCases.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 2/12/21.
//

import XCTest
@testable import AlphaWallet

class StringValidatorTestCases: XCTestCase {
    var validator: StringValidator!
    override func setUp() {
        validator = StringValidator(rules: [
            .lengthLessThanOrEqualTo(10), .lengthMoreThanOrEqualTo(4), .canOnlyContain(.decimalDigits)])
    }

    override func tearDown() {
        validator = nil
    }

    // All 3 rules pass
    func testSuccess() throws {
        switch validator.validate(string: "1234567890") {
        case .success:
            break
        case .failure:
            XCTFail()
        }
    }

    // 1 rule failed
    func testLessFailure() throws {
        switch validator.validate(string: "12345678901") {
        case .success:
            XCTFail()
        case .failure(let StringValidator.Errors.list(failures)):
            for failure in failures {
                switch failure {
                case .lengthLessThanOrEqualTo:
                    continue
                default:
                    XCTFail("\(failures)")
                }
            }
        }
    }

    func testMoreFailure() throws {
        switch validator.validate(string: "123") {
        case .success:
            XCTFail()
        case .failure(let StringValidator.Errors.list(failures)):
            for failure in failures {
                switch failure {
                case .lengthMoreThanOrEqualTo:
                    continue
                default:
                    XCTFail("\(failures)")
                }
            }
        }
    }

    func testContainFailure() throws {
        switch validator.validate(string: "ABCDEFGHIJ") {
        case .success:
            XCTFail()
        case .failure(let StringValidator.Errors.list(failures)):
            for failure in failures {
                switch failure {
                case .canOnlyContain:
                    continue
                default:
                    XCTFail("\(failures)")
                }
            }
        }
    }

    // 2 rules failed
    func testLessContainFailure() throws {
        switch validator.validate(string: "ABCDEFGHIJKLMNOP") {
        case .success:
            XCTFail()
        case .failure(let StringValidator.Errors.list(failures)):
            for failure in failures {
                switch failure {
                case .lengthMoreThanOrEqualTo:
                    XCTFail("\(failures)")
                default:
                    continue
                }
            }
        }
    }

    func testMoreContainFailure() throws {
        switch validator.validate(string: "ABC") {
        case .success:
            XCTFail()
        case .failure(let StringValidator.Errors.list(failures)):
            for failure in failures {
                switch failure {
                case .lengthLessThanOrEqualTo:
                    XCTFail("\(failures)")
                default:
                    continue
                }
            }
        }
    }

    // Impossible for 3 rules to fail

    func testIllegalCharacters() throws {
        let cs1 = CharacterSet(charactersIn: "12345")
        validator = StringValidator(rules: [
            .doesNotContain(cs1)
        ])
        XCTAssert(validator.containsIllegalCharacters(string: "12345"))
        XCTAssertFalse(validator.containsIllegalCharacters(string: "67890"))
        XCTAssert(validator.containsIllegalCharacters(string: "1234567890"))
    }
}
