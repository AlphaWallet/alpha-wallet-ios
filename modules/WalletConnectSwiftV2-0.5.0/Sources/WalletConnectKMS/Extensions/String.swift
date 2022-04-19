

import Foundation


extension String: GenericPasswordConvertible {
    
    public init<D>(rawRepresentation data: D) throws where D : ContiguousBytes {
        let bytes = data.withUnsafeBytes { Data(Array($0)) }
        guard let string = String(data: bytes, encoding: .utf8) else {
            fatalError() // FIXME: Throw error
        }
        self = string
    }
    
    public var rawRepresentation: Data {
        self.data(using: .utf8) ?? Data()
    }
}
