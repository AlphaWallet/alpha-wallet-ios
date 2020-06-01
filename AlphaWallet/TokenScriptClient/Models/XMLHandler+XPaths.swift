// Copyright © 2020 Stormbird PTE. LTD.

import Foundation
import BigInt
import Kanna

extension String {
    func addToXPath(namespacePrefix: String) -> String {
        let components = split(separator: "/")
        let path = components.map { "\(namespacePrefix)\($0)" }.joined(separator: "/")
        if hasPrefix("/") {
            return "/\(path)"
        } else {
            return path
        }
    }
}

extension XMLHandler {
    static func getTokenElement(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XMLElement? {
        return root.at_xpath("/token".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getHoldingContractElement(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XMLElement? {
        let p = xmlContext.namespacePrefix
        return root.at_xpath("/\(p)token/\(p)contract[@name=../\(p)origins/\(p)ethereum/@contract]", namespaces: xmlContext.namespaces)
    }

    static func getContractElementByName(contractName: String, fromRoot root: XMLDocument, xmlContext: XmlContext) -> XMLElement? {
        return root.at_xpath("/token/contract[@name='\(contractName)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getAsnModuleElement(fromRoot root: XMLDocument, xmlContext: XmlContext, forTypeName typeName: String) -> XMLElement? {
        root.at_xpath("asnx:module/namedType[@name='\(typeName)']", namespaces: xmlContext.namespaces)?.parent
    }

    static func getAddressElements(fromContractElement contractElement: Searchable, xmlContext: XmlContext) -> XPathObject {
        return contractElement.xpath("address".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getAddressElementsForHoldingContracts(fromRoot root: XMLDocument, xmlContext: XmlContext, server: RPCServer? = nil) -> XPathObject {
        let p = xmlContext.namespacePrefix
        if let server = server {
            return root.xpath("/\(p)token/\(p)contract[@name=../\(p)origins/\(p)ethereum/@contract]/\(p)address[@network='\(String(server.chainID))']", namespaces: xmlContext.namespaces)
        } else {
            return root.xpath("/\(p)token/\(p)contract[@name=../\(p)origins/\(p)ethereum/@contract]/\(p)address", namespaces: xmlContext.namespaces)
        }
    }

    static func getServerForNativeCurrencyAction(fromRoot root: XMLDocument, xmlContext: XmlContext) -> RPCServer? {
        return root.at_xpath("/action/input/token/ethereum".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)?["network"].flatMap { Int($0) }.flatMap { RPCServer(chainID: $0) }
    }

    static func getAttributeElements(fromAttributeElement element: XMLElement, xmlContext: XmlContext) -> XPathObject {
        return element.xpath("attribute".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getCardAttributeElements(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XPathObject {
        root.xpath("/token/cards/card[@type='action']/attribute".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getMappingElement(fromOriginElement originElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return originElement.at_xpath("mapping".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getNameElement(fromAttributeTypeElement attributeTypeElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        if let nameElement = attributeTypeElement.at_xpath("label[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return nameElement
        } else {
            let fallback = attributeTypeElement.at_xpath("label[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
            return fallback
        }
    }

    static func getBitMask(fromTokenIdElement tokenIdElement: XMLElement) -> BigUInt? {
        guard let bitmask = tokenIdElement["bitmask"] else { return nil }
        return BigUInt(bitmask, radix: 16)
    }

    static func getTokenIdElement(fromAttributeTypeElement attributeTypeElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return attributeTypeElement.at_xpath("origins/token-id".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getSyntaxElement(fromAttributeTypeElement attributeTypeElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return attributeTypeElement.at_xpath("type/syntax".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getEthereumOriginElement(fromAttributeTypeElement attributeTypeElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return attributeTypeElement.at_xpath("origins".addToXPath(namespacePrefix: xmlContext.namespacePrefix) + "/ethereum:call", namespaces: xmlContext.namespaces)
    }

    static func getEthereumOriginElementEvents(fromAttributeTypeElement attributeTypeElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return attributeTypeElement.at_xpath("origins".addToXPath(namespacePrefix: xmlContext.namespacePrefix) + "/ethereum:event", namespaces: xmlContext.namespaces)
    }

    static func getOriginUserEntryElement(fromAttributeTypeElement attributeTypeElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return attributeTypeElement.at_xpath("origins/user-entry".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getEventParameterName(fromEthereumEventElement ethereumEventElement: XMLElement) -> String? {
        guard let eventParameterName = ethereumEventElement["select"] else { return nil }
        return eventParameterName
    }

    static func getEventDefinition(contractElement: XMLElement, asnModuleElement: XMLElement, xmlContext: XmlContext) -> EventDefinition? {
        let addressElements = XMLHandler.getAddressElements(fromContractElement: contractElement, xmlContext: xmlContext)
        guard let address = addressElements.first?.text.flatMap({ AlphaWallet.Address(string: $0.trimmed)}) else { return nil }
        guard let eventName = asnModuleElement.at_xpath("namedType", namespaces: xmlContext.namespaces)?["name"] else { return nil }
        let parameters = asnModuleElement.xpath("namedType/sequence/element", namespaces: xmlContext.namespaces).compactMap { each -> EventParameter? in
            guard let name = each["name"], let type = each["type"] else { return nil }
            let isIndexed = each["indexed"] == "true"
            return .init(name: name, type: type, isIndexed: isIndexed)
        }
        if parameters.isEmpty {
            return nil
        } else {
            return .init(contract: address, name: eventName, parameters: parameters)
        }
    }

    ///The value to be a template containing variables. e.g. for the filter "label=${tokenId}", the extracted name is "label" and value is "${tokenId}"
    static func getEventFilter(fromEthereumEventElement ethereumEventElement: XMLElement) -> (name: String, value: String)? {
        guard let filter = ethereumEventElement["filter"] else { return nil }
        let components = filter.split(separator: "=", maxSplits: 1)
        guard components.count == 2 else { return nil }
        return (name: String(components[0]), value: String(components[1]))
    }

    //Remember `1` in XPath selects the first node, not `0`
    //<plural> tag is optional
    static func getLabelStringElement(fromElement element: XMLElement?, xmlContext: XmlContext) -> XMLElement? {
        guard let tokenElement = element else { return nil }
        if let nameStringElementMatchingLanguage = tokenElement.at_xpath("label/plurals[@xml:lang='\(xmlContext.lang)']/string[@quantity='one']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return nameStringElementMatchingLanguage
        } else if let nameStringElementMatchingLanguage = tokenElement.at_xpath("label/string[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return nameStringElementMatchingLanguage
        } else if let fallbackInPluralsTag = tokenElement.at_xpath("label/plurals[1]/string[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return fallbackInPluralsTag
        } else if let fallbackWithoutPluralsTag = tokenElement.at_xpath("label/string[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return fallbackWithoutPluralsTag
        } else {
            let fallback = tokenElement.at_xpath("label[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
            return fallback
        }
    }

    static func getLabelElementForPluralForm(fromElement element: XMLElement?, xmlContext: XmlContext) -> XMLElement? {
        guard let tokenElement = element else { return nil }
        if let nameStringElementMatchingLanguage = tokenElement.at_xpath("label/plurals[@xml:lang='\(xmlContext.lang)']/string[@quantity='other']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return nameStringElementMatchingLanguage
        } else {
            return getLabelStringElement(fromElement: tokenElement, xmlContext: xmlContext)
        }
    }

    static func getDenialString(fromElement element: XMLElement?, xmlContext: XmlContext) -> XMLElement? {
        guard let element = element else { return nil }
        if let tag = element.at_xpath("denial/string[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return tag
        } else if let tag = element.at_xpath("denial/string[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return tag
        } else {
            let fallback = element.at_xpath("denial[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
            return fallback
        }
    }

    static func getKeyNameElement(fromRoot root: XMLDocument, xmlContext: XmlContext, signatureNamespacePrefix: String) -> XMLElement? {
        let xpath = "/token".addToXPath(namespacePrefix: xmlContext.namespacePrefix) + "/Signature/KeyInfo/KeyName".addToXPath(namespacePrefix: signatureNamespacePrefix)
        return root.at_xpath(xpath, namespaces: xmlContext.namespaces)
    }

    static func getDataElement(fromFunctionElement functionElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return functionElement.at_xpath("data".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getValueElement(fromFunctionElement functionElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return functionElement.at_xpath("value".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getInputs(fromDataElement dataElement: XMLElement) -> XPathObject {
        return dataElement.xpath("*")
    }

    static func getMappingOptionValue(fromMappingElement mappingElement: XMLElement, xmlContext: XmlContext, withKey key: String) -> String? {
        guard let optionElement = mappingElement.at_xpath("option[@key='\(key)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) else { return nil }
        if let valueForLang = optionElement.at_xpath("value[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)?.text {
            return valueForLang
        } else {
            //`1` selects the first node, not `0`
            let fallback = optionElement.at_xpath("value[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)?.text
            return fallback
        }
    }

    static func getTbmlIntroductionElement(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XMLElement? {
        return root.at_xpath("/token/appearance/introduction[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getSelectionElements(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XPathObject {
        let tokenChildren = root.xpath("/token/selection".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
        // swiftlint:disable empty_count
        if tokenChildren.count > 0 {
            // swiftlint:enable empty_count
            return tokenChildren
        } else {
            return root.xpath("/card/selection".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
        }
    }

    static func getTokenScriptTokenInstanceCardElements(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XPathObject {
        return root.xpath("/token/cards/card[@type='action']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getTokenScriptActionOnlyActionElements(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XPathObject {
        return root.xpath("/card[@type='action']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }

    static func getActionTransactionFunctionElement(fromActionElement actionElement: XMLElement, xmlContext: XmlContext) -> XMLElement? {
        return actionElement.at_xpath("transaction".addToXPath(namespacePrefix: xmlContext.namespacePrefix) + "/ethereum:transaction", namespaces: xmlContext.namespaces)
    }

    static func getExcludeSelectionId(fromActionElement actionElement: XMLElement, xmlContext: XmlContext) -> String? {
        actionElement.at_xpath("exclude".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)?["selection"] ?? actionElement["exclude"]
    }

    static func getRecipientAddress(fromEthereumFunctionElement ethereumFunctionElement: XMLElement, xmlContext: XmlContext) -> AlphaWallet.Address? {
        return ethereumFunctionElement.at_xpath("to".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)?.text.flatMap { AlphaWallet.Address(string: $0.trimmed) }
    }

    static func getTokenScriptTokenViewContents(fromViewElement element: XMLElement, xmlContext: XmlContext, xhtmlNamespacePrefix: String) -> (style: String, script: String, body: String) {
        let styleElements = element.xpath("style".addToXPath(namespacePrefix: xhtmlNamespacePrefix), namespaces: xmlContext.namespaces)
        let scriptElements = element.xpath("script".addToXPath(namespacePrefix: xhtmlNamespacePrefix), namespaces: xmlContext.namespaces)
        let bodyElements = element.xpath("body".addToXPath(namespacePrefix: xhtmlNamespacePrefix), namespaces: xmlContext.namespaces)
        let style: String
        let script: String
        let body: String
        // swiftlint:disable empty_count
        if styleElements.count > 0 {
            // swiftlint:enable empty_count
            style = styleElements.compactMap { $0.text }.joined(separator: "\n")
        } else {
            style = ""
        }
        // swiftlint:disable empty_count
        if scriptElements.count > 0 {
            // swiftlint:enable empty_count
            script = scriptElements.compactMap { $0.text }.joined(separator: "\n")
        } else {
            script = ""
        }
        // swiftlint:disable empty_count
        if bodyElements.count > 0 {
            // swiftlint:enable empty_count
            body = bodyElements.compactMap { $0.innerHTML }.joined(separator: "\n")
        } else {
            body = ""
        }
        return (style: style, script: script, body: body)
    }

    static func getTokenScriptTokenItemViewHtmlElement(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XMLElement? {
        if let element = root.at_xpath("/token/cards/card[@type='token']/item-view[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return element
        } else {
            return root.at_xpath("/token/cards/card[@type='token']/item-view[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
        }
    }

    static func getTokenScriptTokenViewHtmlElement(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XMLElement? {
        if let element = root.at_xpath("/token/cards/card[@type='token']/view[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return element
        } else {
            return root.at_xpath("/token/cards/card[@type='token']/view[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
        }
    }

    static func getNameElement(fromActionElement actionElement: Searchable, xmlContext: XmlContext) -> XMLElement? {
        if let element = actionElement.at_xpath("label/string[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return element
        } else if let element = actionElement.at_xpath("label[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return element
        } else {
            return actionElement.at_xpath("label".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
        }
    }

    static func getViewElement(fromActionElement actionElement: Searchable, xmlContext: XmlContext) -> XMLElement? {
        if let element = actionElement.at_xpath("view[@xml:lang='\(xmlContext.lang)']".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces) {
            return element
        } else {
            return actionElement.at_xpath("view[1]".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
        }
    }

    static func getContractElements(fromRoot root: XMLDocument, xmlContext: XmlContext) -> XPathObject {
        return root.xpath("/token/contract".addToXPath(namespacePrefix: xmlContext.namespacePrefix), namespaces: xmlContext.namespaces)
    }
}
