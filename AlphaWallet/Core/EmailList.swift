// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import MailchimpSDK

class EmailList {
    private let listSpecificKey: String

    init(listSpecificKey: String) {
        self.listSpecificKey = listSpecificKey
    }

    ///We skip email validation since MailChimp does it, and this is low volume
    func subscribe(email: String) {
        guard Features.isPromptForEmailListSubscriptionEnabled else { return }
        do {
            try Mailchimp.initialize(token: listSpecificKey, autoTagContacts: true, debugMode: false)
            var contact: Contact = Contact(emailAddress: email)
            contact.status = .subscribed
            Mailchimp.createOrUpdate(contact: contact)
        } catch {
            //TODO log to remote server
            //no-op
        }
    }
}