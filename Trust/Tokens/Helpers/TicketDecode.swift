// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct TicketDecode {

    public static func getName() -> String {
        return "Arranging mortgage"
    }

    public static func getVenue(_ ticketId: Int) -> String {
        let venueID = getVenueID(ticketId)
        if venueID < venues.count {
            return venues[venueID]
        }
        return "unknown"
    }

    public static func getDate(_ ticketId: Int) -> String {
        let venueID = getVenueID(ticketId)
        if venueID < dates.count {
            return dates[venueID]
        }
        return "unknown"
    }

    public static func getZone(_ ticketId: Int) -> String {
        return "Zone " + getZoneChar(ticketId)
    }

    public static func getZoneChar(_ ticketId: Int) -> String {
        let zoneId = getZoneID(ticketId)
        let zone = "A".nextLetterInAlphabet(for: zoneId)!
        return zone
    }

    public static func getSeatIdInt(_ ticketId: Int) -> Int {
        let modifier = getSeatModifier(ticketId)
        let bitmask = (1 << 7) - 1
        return (ticketId & (bitmask)) + modifier
    }

    public static func getPrice(_ ticketId: Int) -> BigInt {
        let milliEth: BigInt = EtherNumberFormatter.full.number(from: "1", units: UnitConfiguration.finneyUnit)!
        let dPrice: Double = 100.0 + (Double(getZoneID(ticketId))) / 2.0 + (Double(getVenueID(ticketId)) / 2.0)
        let bPrice: BigInt = BigInt(dPrice) * milliEth
        return bPrice
    }

    private static func getZoneID(_ ticketId: Int) -> Int {
        let bitmask = (1 << 5) - 1
        let zoneID = ((ticketId >> 7) & (bitmask)) //mask with bottom 5 bits
        return zoneID
    }

    private static func getVenueID(_ ticketId: Int) -> Int {
        return (ticketId >> 12)
    }

    private static func getSeatModifier(_ ticketId: Int) -> Int {
        if getZoneID(ticketId) == 0 && getVenueID(ticketId) == 0 {
            return 0
        }
        return 1
    }

    private static let venues: [String] = [
        "Barclays Pasir Ris Park",
        "RBS Forbidden City",
        "Rabobank Old Changi Hospital",
        "UOB Hacking",
        "CBA Perth",
        "Orange Academy",
        "StGeorge 'Pitz'",
        "NAB NEC",
        "McQuarrie Bierkeller",
        "HSBC Twin Towns",
    ]

    private static let dates: [String] = [
        "28 Feb 2018",
        "05 Mar 2018",
        "20 Mar 2018",
        "31 Mar 2018",
        "01 Apr 2018",
        "20 Apr 2018",
        "30 Apr 2018",
        "05 May 2018",
        "15 May 2018",
        "30 May 2018",
    ]

}
