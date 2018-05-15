// Copyright © 2018 Stormbird PTE. LTD.

import XCTest
@testable import Trust
import UIKit

class TransferTicketsQuantitySelectionViewControllerTests: XCTestCase  {
    func testTransferTicketQuantitySelectionViewControllerCanBeCreated() {
        let token = TokenObject()
        let type = PaymentFlow.send(type: .stormBird(token))
        let ticket = Ticket(id: "1", index: 1, city: "", name: "", venue: "", match: 1, date: Date(), seatId: 1, category: "MATCH CLUB", countryA: "", countryB: "")
        let ticketHolder = TicketHolder(tickets: [ticket], status: .available)
        let controller = TransferTicketsQuantitySelectionViewController(paymentFlow: type)
        let viewModel = TransferTicketsQuantitySelectionViewModel(ticketHolder: ticketHolder)
        controller.configure(viewModel: viewModel)

        XCTAssertNoThrow(controller.view)
    }
}
