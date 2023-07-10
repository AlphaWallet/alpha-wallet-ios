// Copyright © 2023 Stormbird PTE. LTD.

//TODO Some duplicate from AlphaWalletFoundation's Config
fileprivate struct Config {
    fileprivate static func getLocale() -> String? {
        let defaults = UserDefaults.standardOrForTests
        return defaults.string(forKey: Keys.locale)
    }

    struct Keys {
        static let locale = "locale"
    }
}

public extension Date {
    private static var formatsMap: AtomicDictionary<String, DateFormatter> = .init()
    private static var formatsMapLocale: String?

    public init?(string: String, format: String) {
        let date = Date.formatter(with: format).date(from: string)
        if date != nil {
            self = date!
            return
        }
        return nil
    }

    //TODO fix function name. It's returning a string
    public func format(_ format: String, withTimeZone timezone: TimeZone? = nil) -> String {
        return Date.formatter(with: format, withTimeZone: timezone).string(from: self)
    }

    public static func formatter(with format: String, withTimeZone timeZone: TimeZone? = nil) -> DateFormatter {
        if Config.getLocale() != formatsMapLocale {
            formatsMapLocale = Config.getLocale()
            formatsMap = .init()
        }

        var foundFormatter: DateFormatter? = formatsMap[format]
        if foundFormatter == nil {
            foundFormatter = DateFormatter()
            if let locale = Config.getLocale() {
                foundFormatter?.locale = Locale(identifier: locale)
            }
            foundFormatter?.setLocalizedDateFormatFromTemplate(format)
            formatsMap[format] = foundFormatter!
        }
        if let timeZone = timeZone {
            foundFormatter?.timeZone = timeZone
        } else {
            foundFormatter?.timeZone = .current
        }
        return foundFormatter!
    }

    public static var yesterday: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    public static var tomorrow: Date {
        return Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    }

    public func formatAsShortDateString(withTimezone timezone: TimeZone? = nil) -> String {
        return format("dd MMM yyyy", withTimeZone: timezone)
    }

    public func isEarlierThan(date: Date) -> Bool {
        return date.timeIntervalSince(self) > 0
    }
}
