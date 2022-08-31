// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

#if targetEnvironment(simulator)
//no-op
#else
import MailchimpSDK
#endif

public class EmailList {
    private let listSpecificKey: String

    public init(listSpecificKey: String) {
        self.listSpecificKey = listSpecificKey
    }

    ///We skip email validation since MailChimp does it, and this is low volume
    public func subscribe(email: String) {
        guard Features.default.isAvailable(.isPromptForEmailListSubscriptionEnabled) else { return }
        #if targetEnvironment(simulator)
        //no-op
        #else
        do {
            try Mailchimp.initialize(token: listSpecificKey, autoTagContacts: true, debugMode: false)
            var contact: Contact = Contact(emailAddress: email)
            contact.status = .subscribed
            Mailchimp.createOrUpdate(contact: contact)
        } catch {
            //TODO log to remote server
            //no-op
        }
        #endif
    }
}
