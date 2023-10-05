// Copyright © 2023 Stormbird PTE. LTD.

import Foundation
import WebKit

public enum SetProperties {
    public static let setActionProps = "setActionProps"
    //Values ought to be typed. But it's just much easier to keep them as `Any` and convert them to the correct types when accessed (based on TokenScript syntax and XML tag). We don't know what those are here
    public typealias Properties = [String: Any]

    case action(id: Int, changedProperties: Properties)

    public static func fromMessage(_ message: WKScriptMessage) -> SetProperties? {
        guard message.name == SetProperties.setActionProps else { return nil }
        guard let body = message.body as? [String: AnyObject] else { return nil }
        guard let changedProperties = body["object"] as? SetProperties.Properties else { return nil }
        guard let id = body["id"] as? Int else { return nil }
        return .action(id: id, changedProperties: changedProperties)
    }
}
