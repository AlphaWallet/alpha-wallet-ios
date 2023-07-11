//
//  EnsTextRecordKey.swift
//  AlphaWalletENS
//
//  Created by Hwee-Boon Yar on Apr/9/22.

public enum EnsTextRecordKey: Equatable, Hashable {
    /// A URL to an image used as an avatar or logo
    case avatar
    /// A description of the name
    case description
    /// A canonical display name for the ENS name; this MUST match the ENS name when its case is folded, and clients should ignore this value if it does not (e.g. "ricmoo.eth" could set this to "RicMoo.eth")
    case display
    /// An e-mail address
    case email
    /// A list of comma-separated keywords, ordered by most significant first; clients that interpresent this field may choose a threshold beyond which to ignore
    case keywords
    /// A physical mailing address
    case mail
    /// A notice regarding this name
    case notice
    /// A generic location (e.g. "Toronto, Canada")
    case location
    /// A phone number as an E.164 string
    case phone
    /// A website URL
    case url

    case custom(String)

    public var rawValue: String {
        switch self {
        case .avatar: return "avatar"
        case .description: return "description"
        case .display: return "display"
        case .email: return "email"
        case .keywords: return "keywords"
        case .notice: return "notice"
        case .location: return "location"
        case .phone: return "phone"
        case .url: return "url"
        case .custom(let value): return value
        case .mail: return "mail"
        }
    }
}

public extension EnsTextRecordKey {
    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "avatar": self = .avatar
        case "description": self = .description
        case "display": self = .display
        case "email": self = .email
        case "keywords": self = .keywords
        case "notice": self = .notice
        case "location": self = .location
        case "phone": self = .phone
        case "url": self = .url
        case "mail": self = .mail
        default: self = .custom(rawValue)
        }
    }
}
