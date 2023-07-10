// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress
import Combine

//This struct makes it easier to listen to when all the attribute values are available (specifically values from smart contract function calls are available asynchronously)
public struct AssetAttributeValues {
    private let attributeValues: [AttributeId: AssetInternalValue]
    public init(attributeValues: [AttributeId: AssetInternalValue]) {
        self.attributeValues = attributeValues
    }

    public init(attributeValues: [AttributeId: AssetAttributeSyntaxValue]) {
        self.init(attributeValues: attributeValues.mapValues { $0.value })
    }

    public func resolveAllAttributes() -> AnyPublisher<[AttributeId: AssetInternalValue], Never> {
        let publishers = attributeValues
            .compactMap { value -> AnyPublisher<(AttributeId, AssetInternalValue?), Never>? in
                if case .subscribable(let subscribable) = value.value {
                    if let subscribedValue = subscribable.value {
                        return .just((value.key, subscribedValue))
                    } else {
                        return subscribable.publisher
                            .map { (value.key, $0) }
                            .first()
                            .eraseToAnyPublisher()
                    }
                } else {
                    return .just((value.key, value.value))
                }
            }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { values -> [AttributeId: AssetInternalValue] in
                var result: [AttributeId: AssetInternalValue] = [:]
                for each in values {
                    if result[each.0] != nil {
                        //no-op
                    } else {
                        result[each.0] = each.1
                    }
                }

                return result
            }.eraseToAnyPublisher()
    }
}
