//
//  Base64Decoder.swift
//  Alamofire
//
//  Created by Vladyslav Shepitko on 23.02.2023.
//

import Foundation

public struct Base64Decoder {
    public typealias Response = (mimeType: String?, encoding: Encoding?, data: Data)

    public enum Encoding {
        case base64
        case other(String)

        init(string: String) {
            switch string {
            case "base64":
                self = .base64
            default:
                self = .other(string)
            }
        }
    }

    public init() {}

    /// for strings like: "data:application/json;base64,ewogICJuYW1lIjogIk5GVFdvcmxkcyBBdmF0YXIgTWludCBQYXNzIiwKICAiZGVzY3JpcHRpb24iOiAiQnkgW1l1Z2FMYWJzXShodHRwczovL29wZW5zZWEuaW8vWXVnYUxhYnMpXHJcblxyXG5QYXNzIHRvIHRha2UgcGFydCBpbiBORlRXb3JsZHMgQXZhdGFyIE1pbnQuXHJcblxyXG5UaGVzZSBhdmF0YXJzIHdpbGwgY292ZXIgdGhlIGludGVybmV0IGZvciBodW5kcmVkcyBvZiB5ZWFycy5cclxuXHJcbk5vdyBpcyB5b3VyIGNoYW5jZSB0byBnZXQgYXZhdGFyIGZvciBjZW50dXJ5IiwKICAiaW1hZ2UiOiAiaHR0cHM6Ly9pcGZzLmlvL2lwZnMvUW1YOTVvOG5Wd1I3a0djclRpeVU4b1N0ZGJudnFQTlRXWVA5UWQ4NXlOWXF4UCIsCiAgImV4dGVybmFsX3VybCI6ICJodHRwczovL25mdHdvcmxkYXZhdGFyLnh5eiIKfQ=="
    public func decode(string: String) -> Response? {
        let predicate = NSPredicate(format: "SELF MATCHES %@", "^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)$")

        if let index = string.firstIndex(where: { $0 == "," }) {
            guard index < string.endIndex else { return nil }

            let startBase64Index = string.index(index, offsetBy: 1)
            let supposeBase64 = String(string[startBase64Index ..< string.endIndex])
            let isBase64 = predicate.evaluate(with: supposeBase64) || Data(base64Encoded: supposeBase64) != nil
            if isBase64 {
                guard let data = Data(base64Encoded: supposeBase64) else { return nil }
                //data:application/json;base64,
                let dataEncodingType = String(string[string.startIndex ..< index])
                let components = dataEncodingType.components(separatedBy: ";")

                guard components.count == 2 else {
                    return (nil, nil, data)
                }
                let mimeType = components[0].components(separatedBy: ":")[1]
                let encoding = Encoding(string: components[1])

                return (mimeType, encoding, data)
            } else {
                return nil
            }
        } else {
            let isBase64 = predicate.evaluate(with: string) || Data(base64Encoded: string) != nil
            if isBase64, let data = Data(base64Encoded: string) {
                return (nil, nil, data)
            }
        }

        return nil
    }
}
