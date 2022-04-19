import XCTest
@testable import WalletConnect

final class EitherTests: XCTestCase {
    
    func testLeftValue() {
        let value = "string"
        let either = Either<String, Int>(value)
        XCTAssertEqual(either.left, value)
        XCTAssertNil(either.right)
    }
    
    func testRightValue() {
        let value = 1
        let either = Either<String, Int>(value)
        XCTAssertEqual(either.right, value)
        XCTAssertNil(either.left)
    }
    
    func testEquality() {
        XCTAssert(Either<Int, Int>.left(1) == Either<Int, Int>.left(1))
        XCTAssert(Either<Int, Int>.right(1) == Either<Int, Int>.right(1))
        XCTAssert(Either<Int, Int>.left(1) != Either<Int, Int>.right(1))
        XCTAssert(Either<Int, Int>.right(1) != Either<Int, Int>.left(1))
    }
    
    func testCodableRoundTripLeft() throws {
        let either = Either<String, Int>("string")
        let encoded = try JSONEncoder().encode(either)
        let decoded = try JSONDecoder().decode(Either<String, Int>.self, from: encoded)
        XCTAssertEqual(decoded, either)
    }
    
    func testCodableRoundTripRight() throws {
        let either = Either<String, Int>(1)
        let encoded = try JSONEncoder().encode(either)
        let decoded = try JSONDecoder().decode(Either<String, Int>.self, from: encoded)
        XCTAssertEqual(decoded, either)
    }
    
    func testDecodingFail() throws {
        let either = Either<Int, Int>.left(1)
        let encoded = try JSONEncoder().encode(either)
        XCTAssertThrowsError(try JSONDecoder().decode(Either<String, String>.self, from: encoded))
    }
}
