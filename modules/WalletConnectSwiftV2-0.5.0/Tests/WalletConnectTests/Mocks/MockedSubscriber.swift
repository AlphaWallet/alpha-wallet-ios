
import Foundation
@testable import WalletConnect

class MockedSubscriber: WCSubscribing {

    var onReceivePayload: ((WCRequestSubscriptionPayload)->())?

    private(set) var subscriptions: [String] = []
    private(set) var unsubscriptions: [String] = []

    func setSubscription(topic: String) {
        subscriptions.append(topic)
    }

    func getSubscription(topic: String) -> String? {
        fatalError()
    }

    func removeSubscription(topic: String) {
        if subscriptions.contains(topic) {
            unsubscriptions.append(topic)
        }
        subscriptions.removeAll { $0 == topic }
    }
}

extension MockedSubscriber {

    func didSubscribe(to topic: String) -> Bool {
        subscriptions.contains { $0 == topic }
    }
    
    func didUnsubscribe(to topic: String) -> Bool {
        unsubscriptions.contains { $0 == topic }
    }
}
