import Foundation

extension URL {
    
    static func stub() -> URL {
        URL(string: "https://httpbin.org")!
    }
}
