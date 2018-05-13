//
//  Date.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation

public extension Date {

    private static var formatsMap: [String: DateFormatter] = [:]
    private static var formatsMapLocale: String?

    public init?(string: String, format: String) {
        let date = Date.formatter(with: format).date(from: string)
        if date != nil {
            self = date!
            return
        }
        return nil
    }

    public func format(_ format: String) -> String {
        return Date.formatter(with: format).string(from: self)
    }
    
    public static func formatter(with format: String) -> DateFormatter {
        let config = Config()
        if config.locale != formatsMapLocale {
            formatsMapLocale = config.locale
            formatsMap = Dictionary()
        }

        var foundFormatter = formatsMap[format]
        if foundFormatter == nil {
            foundFormatter = DateFormatter()
            if let locale = config.locale {
                foundFormatter?.locale = Locale(identifier: locale)
            }
            foundFormatter?.setLocalizedDateFormatFromTemplate(format)
            formatsMap[format] = foundFormatter!
        }
        return foundFormatter!
    }

    public static var yesterday: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    public static var tomorrow: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    }

    public func formatAsShortDateString() -> String {
        return format("dd MMM")
    }
}
