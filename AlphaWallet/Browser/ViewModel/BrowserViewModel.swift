//
//  BrowserViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.03.2023.
//

import Foundation
import UIKit
import WebKit
import JavaScriptCore
import AlphaWalletFoundation
import AlphaWalletLogger
import Combine

struct BrowserViewModelInput {
    let progress: AnyPublisher<Double, Never>
    let decidePolicy: AnyPublisher<BrowserViewModel.DecidePolicy, Never>
}

struct BrowserViewModelOutput {
    let progressBarState: AnyPublisher<BrowserViewModel.ProgressBarState, Never>
    let universalLink: AnyPublisher<URL, Never>
    let recordUrl: AnyPublisher<Void, Never>
    let dappAction: AnyPublisher<(action: DappAction, callbackId: Int), Never>
}

class BrowserViewModel: NSObject {
    static let userClient: String = Keys.ClientName + "/" + (Bundle.main.versionNumber ?? "") + " 1inchWallet"

    private let wallet: Wallet
    private let server: RPCServer
    private let recordUrlSubject = PassthroughSubject<Void, Never>()
    private let universalLinkSubject = PassthroughSubject<URL, Never>()
    private let dappActionSubject = PassthroughSubject<(action: DappAction, callbackId: Int), Never>()
    private var cancellable = Set<AnyCancellable>()

    lazy var config: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration.make(forType: .dappBrowser(server), address: wallet.address, messageHandler: ScriptMessageProxy(delegate: self))
        config.websiteDataStore = WKWebsiteDataStore.default()
        return config
    }()
    
    init(wallet: Wallet, server: RPCServer) {
        self.wallet = wallet
        self.server = server
        super.init()
    }

    func transform(input: BrowserViewModelInput) -> BrowserViewModelOutput {
        input.decidePolicy
            .sink { [weak self] in self?.handle(decidePolicy: $0) }
            .store(in: &cancellable)

        let progress = input.progress
            .map { BrowserViewModel.ProgressBarState(value: Float($0), isHidden: $0 == 1) }

        return .init(
            progressBarState: progress.eraseToAnyPublisher(),
            universalLink: universalLinkSubject.eraseToAnyPublisher(),
            recordUrl: recordUrlSubject.eraseToAnyPublisher(),
            dappAction: dappActionSubject.eraseToAnyPublisher())
    }

    private func handle(decidePolicy: BrowserViewModel.DecidePolicy) {
        infoLog("[Browser] decidePolicyFor url: \(String(describing: decidePolicy.navigationAction.request.url?.absoluteString))")

        guard let url = decidePolicy.navigationAction.request.url, let scheme = url.scheme else {
            decidePolicy.decisionHandler(.allow)
            return
        }
        let app = UIApplication.shared
        if ["tel", "mailto"].contains(scheme), app.canOpenURL(url) {
            app.open(url)
            decidePolicy.decisionHandler(.cancel)
            return
        }

        //TODO extract `DeepLink`, if reasonable
        if url.host == "aw.app" && url.path == "/wc", let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.queryItems.isEmpty {
            infoLog("[Browser] Swallowing URL and doing a no-op, url: \(url.absoluteString)")
            decidePolicy.decisionHandler(.cancel)
            return
        }

        if DeepLink.supports(url: url) {
            universalLinkSubject.send(url)
            decidePolicy.decisionHandler(.cancel)
            return
        }

        decidePolicy.decisionHandler(.allow)
    }
}

extension BrowserViewModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let command = DappAction.fromMessage(message) else {
            if message.name == Browser.locationChangedEventName {
                recordUrlSubject.send(())
            }
            return
        }
        infoLog("[Browser] dapp command: \(command)")
        let action = DappAction.fromCommand(command, server: server, transactionType: .prebuilt(server))

        infoLog("[Browser] dapp action: \(action)")
        dappActionSubject.send((action: action, callbackId: command.id))
    }
}

extension BrowserViewModel {

    struct Keys {
        static let developerExtrasEnabled = "developerExtrasEnabled"
        static let ClientName = "AlphaWallet"
    }

    struct ProgressBarState {
        let value: Float
        let isHidden: Bool
    }

    typealias DecisionHandler = (WKNavigationActionPolicy) -> Void
    typealias DecidePolicy = (navigationAction: WKNavigationAction, decisionHandler: DecisionHandler)
}
