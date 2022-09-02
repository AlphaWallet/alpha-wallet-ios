//
//  ShareContentAction.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation

public enum ShareContentAction {
    static let scheme = "awallet"

    private enum Host: String {
        case openURL
        case openText
        case openApp
    }

    case url(URL)
    case string(String)
    case openApp

    public init?(_ url: URL) {
        guard let scheme = url.scheme, scheme == ShareContentAction.scheme else {
            return nil
        }
        guard let hostValue = url.host, let host = Host(rawValue: hostValue) else {
            self = .openApp
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        switch host {
        case .openURL:
            guard let value = components?.queryItemValue(name: "q"), let param = URL(string: value) else {
                return nil
            }
            self = .url(param)
        case .openText:
            guard let value = components?.queryItemValue(name: "q") else {
                return nil
            }
            self = .string(value)
        case .openApp:
            //Impossible to reach here
            return nil
        }
    }

    public var host: String {
        switch self {
        case .url:
            return Host.openURL.rawValue
        case .string:
            return Host.openText.rawValue
        case .openApp:
            return ""
        }
    }

    public var url: URL? {
        return params.url
    }

    private var params: URLComponents {
        var components = URLComponents()
        components.scheme = ShareContentAction.scheme
        components.host = host
        components.path = "/"

        switch self {
        case .url(let url):
            components.queryItems = [
                .init(name: "q", value: url.absoluteString)
            ]
        case .string(let text):
            components.queryItems = [
                .init(name: "q", value: text)
            ]
        case .openApp:
            return .init()
        }

        return components
    }
}

private extension URLComponents {
    func queryItemValue(name: String) -> String? {
        return queryItems?.first(where: { $0.name == name })?.value
    }
}
