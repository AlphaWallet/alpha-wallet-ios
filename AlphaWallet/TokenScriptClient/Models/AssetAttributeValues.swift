// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

//This class makes it easier to listen to when all the attribute values are available (specifically values from smart contract function calls are available asynchronously)
class AssetAttributeValues {
    private let attributeValues: [AttributeId: AssetInternalValue]
    private var resolvedAttributeValues = [AttributeId: AssetInternalValue]()

    var isAllResolved: Bool {
        return resolvedAttributeValues.count == attributeValues.count
    }

    init(attributeValues: [AttributeId: AssetInternalValue]) {
        self.attributeValues = attributeValues
    }

    convenience init(attributeValues: [AttributeId: AssetAttributeSyntaxValue]) {
        self.init(attributeValues: attributeValues.mapValues { $0.value })
    }

    func resolve(withUpdatedBlock block: @escaping ([AttributeId: AssetInternalValue]) -> Void) -> [AttributeId: AssetInternalValue] {
        var subscribedAttributes = [Subscribable<AssetInternalValue>]()
        for (name, value) in attributeValues {
            if case .subscribable(let subscribable) = value {
                if let subscribedValue = subscribable.value {
                    resolvedAttributeValues[name] = subscribedValue
                } else {
                    if !subscribedAttributes.contains(where: { $0 === subscribable }) {
                        subscribedAttributes.append(subscribable)
                        subscribable.subscribe { value in
                            guard let value = value else { return }
                            self.resolvedAttributeValues[name] = value
                            block(self.resolvedAttributeValues)
                        }
                    }
                }
            } else {
                resolvedAttributeValues[name] = value
            }
        }
        return resolvedAttributeValues
    }
}
