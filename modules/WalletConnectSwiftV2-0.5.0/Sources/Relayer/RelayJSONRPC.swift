// 

import Foundation

enum RelayJSONRPC {
    enum Method: String {
        case subscribe = "waku_subscribe"
        case publish = "waku_publish"
        case subscription = "waku_subscription"
        case unsubscribe = "waku_unsubscribe"
    }
    
    struct PublishParams: Codable, Equatable {
        let topic: String
        let message: String
        let ttl: Int
        let prompt: Bool?
    }
    
    struct SubscribeParams: Codable, Equatable {
        let topic: String
    }
    
    struct SubscriptionData: Codable, Equatable {
        let topic: String
        let message: String
    }
    
    struct SubscriptionParams: Codable, Equatable {
        let id: String
        let data: SubscriptionData
    }
    
    struct UnsubscribeParams: Codable, Equatable {
        let id: String
        let topic: String
    }
}
