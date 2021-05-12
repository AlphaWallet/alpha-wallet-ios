//
//  XYMarkerView.swift
//  ChartsDemo
//  Copyright © 2016 dcg. All rights reserved.
//

import Foundation
import Charts
#if canImport(UIKit)
    import UIKit
#endif

open class XYMarkerView: BalloonMarker {
    fileprivate var yFormatter = NumberFormatter()
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy HH:mm"

        return formatter
    }()

    open override func refreshContent(entry: ChartDataEntry, highlight: Highlight) {
        let date = Date(timeIntervalSince1970: TimeInterval(entry.x))
        let usdValue = NumberFormatter.usd.string(from: entry.y) ?? "-"
        let dateValue = XYMarkerView.dateFormatter.string(from: date)

        setLabel("\(dateValue)\n\(usdValue)")
    }
    
}
