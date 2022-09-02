// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletAddress

//This class makes it easier to listen to when all the attribute values are available (specifically values from smart contract function calls are available asynchronously)

public class AssetAttributeValues {
    private let attributeValues: AtomicDictionary<AttributeId, AssetInternalValue>
    private let resolvedAttributeValues: AtomicDictionary<AttributeId, AssetInternalValue> = .init()

    public var isAllResolved: Bool {
        return resolvedAttributeValues.count == attributeValues.count
    }

    public init(attributeValues: [AttributeId: AssetInternalValue]) {
        self.attributeValues = .init(value: attributeValues)
    }

    public convenience init(attributeValues: [AttributeId: AssetAttributeSyntaxValue]) {
        self.init(attributeValues: attributeValues.mapValues { $0.value })
    }

    public func resolve(withUpdatedBlock block: @escaping ([AttributeId: AssetInternalValue]) -> Void) -> [AttributeId: AssetInternalValue] {
        var subscribedAttributes = [Subscribable<AssetInternalValue>]()
        for (name, value) in attributeValues.values {
            if case .subscribable(let subscribable) = value {
                if let subscribedValue = subscribable.value {
                    resolvedAttributeValues[name] = subscribedValue
                } else {
                    if !subscribedAttributes.contains(where: { $0 === subscribable }) {
                        subscribedAttributes.append(subscribable)
                        //TODO fix objects being retained. Cannot only make [weak self] because TokenScript values wouldn't be resolved
                        subscribable.subscribe { value in
                            guard let value = value else { return }
                            self.resolvedAttributeValues[name] = value
                            block(self.resolvedAttributeValues.values)
                        }
                    }
                }
            } else {
                resolvedAttributeValues[name] = value
            }
        }
        return resolvedAttributeValues.values
    }
}
