//
//  UrlSchemeCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2020.
//

import Foundation

protocol UrlSchemeResolver: AnyObject {
    func openURLInBrowser(url: URL)
}

protocol UrlSchemeCoordinatorDelegate: AnyObject {
    func resolve(for coordinator: UrlSchemeCoordinator) -> UrlSchemeResolver?
}

protocol UrlSchemeCoordinatorType {
    func handleOpen(url: URL) -> Bool
    func processPendingURL(in inCoordinator: UrlSchemeResolver)
}

class UrlSchemeCoordinator: UrlSchemeCoordinatorType {
    var pendingUrl: URL?

    weak var delegate: UrlSchemeCoordinatorDelegate?

    @discardableResult func handleOpen(url: URL) -> Bool {
        if canHandle(url: url) {
            if let inCoordinator = delegate?.resolve(for: self) {
                self.process(url: url, with: inCoordinator)
            } else {
                pendingUrl = url
            }

            return true
        } else {
            return false
        }
    }

    func processPendingURL(in inCoordinator: UrlSchemeResolver) {
        guard let url = pendingUrl else { return }

        process(url: url, with: inCoordinator)
    }

    private func process(url: URL, with inCoordinator: UrlSchemeResolver) {
        switch ShareContentAction(url) {
        case .none, .string:
            break //NOTE: here we can add parsing Addresses from string
        case .url(let url):
            inCoordinator.openURLInBrowser(url: url)
        case .openApp:
            //No-op. Just switching to the app
            break
        }

        pendingUrl = .none
    }

    private func canHandle(url: URL) -> Bool {
        return ShareContentAction(url) != nil
    }
}
