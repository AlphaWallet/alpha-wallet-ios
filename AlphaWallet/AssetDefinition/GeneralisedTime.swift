// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct GeneralisedTime {
    static var formattersForLocalTime = [TimeZone: DateFormatter]()

    var date: Date
    var timeZone: TimeZone
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmssz"
        return formatter
    }()
    var formatAsGeneralisedTime: String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMddHHmmssZ"
        df.timeZone = timeZone
        return df.string(from: date)
    }

    //Return value is JavaScript dictionary with venue and locale as keys. If the TokenScript author wants to display the venue/event date, just display venue in their device locale, otherwise use the locale value
    var formatTimeToLocaleAndVenueStringEquivalent: String {
        let utcTimeZone = TimeZone.init(abbreviation: "UTC")
        let dfForUtc = formatterForLocalTime(forTimeZone: utcTimeZone!)
        let dateStringForUtc = dfForUtc.string(from: date)
        let generalisedTime = formatAsGeneralisedTime
        let result = """
                     {
                     date: new Date(\"\(dateStringForUtc)\"),
                     generalizedTime: \"\(generalisedTime)\"
                     }\n
                     """
        return result
    }

    //TODO be good to remove this and use an optional instead
    public init() {
        self.date = Date()
        self.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    init?(string: String) {
        guard let date = GeneralisedTime.formatter.date(from: string) else { return nil }
        guard let seconds = GeneralisedTime.extractTimeZoneSecondsFromGMT(string: string) else { return nil }
        guard let timeZone = TimeZone(secondsFromGMT: seconds) else { return nil }
        self.date = date
        self.timeZone = timeZone
    }

    /// Given "20180619210000+0300", extract "+0300" and convert to seconds
    private static func extractTimeZoneSecondsFromGMT(string: String) -> Int? {
        let pattern = "([+-])(\\d\\d)(\\d\\d)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.count))
        guard matches.count == 1 else { return nil }
        guard matches[0].numberOfRanges == 4 else { return nil }
        if let sign = Range(matches[0].range(at: 1), in: string), let hour = Range(matches[0].range(at: 2), in: string), let minute = Range(matches[0].range(at: 3), in: string) {
            if let hour = Int(string[hour]), let minute = Int(string[minute]) {
                let sign = string[sign]
                guard sign == "+" || sign == "-" else {
                    return nil
                }
                let seconds = (hour * 60 + minute) * 60
                if sign == "-" {
                    return seconds * -1
                } else {
                    return seconds
                }
            }
        }
        return nil
    }

    public func formatAsShortDateString() -> String {
        return date.format("dd MMM yyyy", withTimeZone: timeZone)
    }

    public func format(_ string: String) -> String {
        return date.format(string, withTimeZone: timeZone)
    }

    private func formatterForLocalTime(forTimeZone timeZone: TimeZone) -> DateFormatter {
        if let formatter = GeneralisedTime.formattersForLocalTime[timeZone] {
            return formatter
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.timeZone = timeZone
            GeneralisedTime.formattersForLocalTime[timeZone] = formatter
            return formatter
        }
    }
}

func < (lhs: GeneralisedTime, rhs: GeneralisedTime) -> Bool {
    return lhs.date < rhs.date
}
