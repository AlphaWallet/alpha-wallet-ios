// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

//kkk use in AssetDefinitionStore
private var httpHeaderLastModifiedDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "E, dd MMM yyyy HH:mm:ss z"
    df.timeZone = TimeZone(secondsFromGMT: 0)
    return df
}()

func string(fromHTTPHeaderLastModifiedDate date: Date) -> String {
    return httpHeaderLastModifiedDateFormatter.string(from: date)
}

func httpHeaderLastModifiedDate(fromString string: String) -> Date? {
    return httpHeaderLastModifiedDateFormatter.date(from: string)
}
