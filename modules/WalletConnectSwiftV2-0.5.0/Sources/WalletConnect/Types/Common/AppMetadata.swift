
import Foundation

/// App metadata object that describes application metadata.
public struct AppMetadata: Codable, Equatable {
    public init(name: String?, description: String?, url: String?, icons: [String]?) {
        self.name = name
        self.description = description
        self.url = url
        self.icons = icons
    }
    
    public let name: String?
    public let description: String?
    public let url: String?
    public let icons: [String]?
}
