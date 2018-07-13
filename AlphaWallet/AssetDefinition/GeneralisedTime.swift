// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct GeneralisedTime {
    var date: Date
    var timeZone: TimeZone
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmssz"
        return formatter
    }()

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
}

func <(lhs: GeneralisedTime, rhs: GeneralisedTime) -> Bool {
    return lhs.date < rhs.date
}
