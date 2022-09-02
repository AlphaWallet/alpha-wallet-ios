//
//  XYMarkerView.swift
//  ChartsDemo
//  Copyright © 2016 dcg. All rights reserved.
//

import Foundation
import Charts
import AlphaWalletFoundation
#if canImport(UIKit)
    import UIKit
#endif

open class XYMarkerView: BalloonMarker {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy HH:mm"

        return formatter
    }()

    open override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        let date = Date(timeIntervalSince1970: TimeInterval(entry.x))
        let usdValue = Formatter.usd.string(from: entry.y) ?? "-"
        let dateValue = XYMarkerView.dateFormatter.string(from: date)

        setLabel("\(dateValue)\n\(usdValue)")
    }
    
}
