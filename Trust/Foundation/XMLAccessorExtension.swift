//
//  XMLAccessorExtension.swift
//  AlphaWallet
//
//  Created by James Sangalli on 26/5/18.
//

import Foundation
import SwiftyXMLParser

extension XML.Accessor {
    func getElement(attributeName: String, attributeValue: String) -> XML.Accessor? {
        switch self {
        case .singleElement(let element):
            let attributeIsCorrect = element.attributes[attributeName] == attributeValue
            if attributeIsCorrect {
                return XML.Accessor(element)
            } else {
                return nil
            }
        case .sequence(let elements):
            if let element = elements.first(where: { $0.attributes[attributeName] == attributeValue }) {
                return XML.Accessor(element)
            } else {
                return nil
            }
        case .failure:
            return nil
        }
    }
    
    func getElementWithKeyAttribute(equals value: String) -> XML.Accessor? {
        return getElement(attributeName: "key", attributeValue: value)
    }
    
    func getElementWithLangAttribute(equals value: String) -> XML.Accessor? {
        return getElement(attributeName: "lang", attributeValue: value)
    }
}
