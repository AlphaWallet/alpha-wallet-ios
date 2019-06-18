// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

//This class makes it easier to listen to when all the attribute values are available (specifically values from smart contract function calls are available asynchronously)
class AssetAttributeValues {
    private let attributeNameValues: [String: AssetInternalValue]
    private var resolvedAttributeNameValues = [String: AssetInternalValue]()

    var isAllResolved: Bool {
        return resolvedAttributeNameValues.count == attributeNameValues.count
    }

    init(attributeNameValues: [String: AssetInternalValue]) {
        self.attributeNameValues = attributeNameValues
    }

    convenience init(attributeNameValues: [String: AssetAttributeSyntaxValue]) {
        self.init(attributeNameValues: attributeNameValues.mapValues { $0.value })
    }

    func resolve(withUpdatedBlock block: @escaping ([String: AssetInternalValue]) -> Void) -> [String: AssetInternalValue] {
        var subscribedAttributes = [Subscribable<AssetInternalValue>]()
        for (name, value) in attributeNameValues {
            if case .subscribable(let subscribable) = value {
                if let subscribedValue = subscribable.value {
                    resolvedAttributeNameValues[name] = subscribedValue
                } else {
                    if !subscribedAttributes.contains(where: { $0 === subscribable }) {
                        subscribedAttributes.append(subscribable)
                        subscribable.subscribe { value in
                            guard let value = value else { return }
                            self.resolvedAttributeNameValues[name] = value
                            block(self.resolvedAttributeNameValues)
                        }
                    }
                }
            } else {
                resolvedAttributeNameValues[name] = value
            }
        }
        return resolvedAttributeNameValues
    }
}
