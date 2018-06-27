//Copyright © 2018 Stormbird PTE. LTD.

import FBSnapshotTestCase
@testable import Trust
import UIKit

class TransferTicketsQuantitySelectionViewControllerTests: FBSnapshotTestCase  {
    override func setUp() {
        super.setUp()
        isDeviceAgnostic = true
        recordMode = false
    }

//    func testTransferTicketQuantitySelectionViewControllerCanBeCreated() {
//        let token = TokenObject()
//        let type = PaymentFlow.send(type: .stormBird(token))
//        let ticket = Ticket(id: "1", index: 1, city: "", name: "", venue: "", match: 9, date: GeneralisedTime(string: "20010203160500+0300")!, seatId: 1, category: "MATCH CLUB", countryA: "Team A", countryB: "Team B")
//        let ticketHolder = TicketHolder(tickets: [ticket], status: .available, contractAddress: "0x1")
//        let controller = TransferTicketsQuantitySelectionViewController(paymentFlow: type)
//        let viewModel = TransferTicketsQuantitySelectionViewModel(token: TokenObject(), ticketHolder: ticketHolder)
//        controller.configure(viewModel: viewModel)
//
//        FBSnapshotVerifyView(controller.view)
//    }
}
