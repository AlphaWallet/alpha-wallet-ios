// Copyright © 2023 Stormbird PTE. LTD.

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
    public var jsonString: String? {
        if let dict = (self as AnyObject) as? [String: AnyObject] {
            do {
                let data = try Data(json: dict, options: JSONSerialization.WritingOptions(rawValue: 0))
                if let string = String(data: data, encoding: String.Encoding.utf8) {
                    return string
                }
            } catch {
                //no op
            }
        }
        return nil
    }
}
