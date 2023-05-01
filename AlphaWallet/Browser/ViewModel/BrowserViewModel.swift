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
    let keyboardAction: AnyPublisher<BrowserViewModel.KeyboardAction, Never>
}

class BrowserViewModel: NSObject {
    static let userClient: String = Keys.ClientName + "/" + (Bundle.main.versionNumber ?? "") + " 1inchWallet"

    private let wallet: Wallet
    private let server: RPCServer
    private let recordUrlSubject = PassthroughSubject<Void, Never>()
    private let universalLinkSubject = PassthroughSubject<URL, Never>()
    private let dappActionSubject = PassthroughSubject<(action: DappAction, callbackId: Int), Never>()
    private var cancellable = Set<AnyCancellable>()
    private var keyboardStatePublisher: AnyPublisher<KeyboardChecker.KeyboardState, Never> {
        let keyboardNotifications: [NSNotification.Name] = [
            UIResponder.keyboardWillShowNotification,
            UIResponder.keyboardWillHideNotification,
        ]

        return Publishers.MergeMany(keyboardNotifications.map { NotificationCenter.default.publisher(for: $0) })
            .map { KeyboardChecker.KeyboardState(with: $0) }
            .eraseToAnyPublisher()
    }

    lazy var config: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration.make(forType: .dappBrowser(server), address: wallet.address, messageHandler: ScriptMessageProxy(delegate: self))
        config.websiteDataStore = WKWebsiteDataStore.default()
        return config
    }()
    let browserOnly: Bool
    
    init(wallet: Wallet, server: RPCServer, browserOnly: Bool) {
        self.wallet = wallet
        self.server = server
        self.browserOnly = browserOnly
        super.init()
    }

    func transform(input: BrowserViewModelInput) -> BrowserViewModelOutput {
        input.decidePolicy
            .sink { [weak self] in self?.handle(decidePolicy: $0) }
            .store(in: &cancellable)

        let progress = input.progress
            .map { BrowserViewModel.ProgressBarState(value: Float($0), isHidden: $0 == 1) }

        let keyboardAction = keyboardStatePublisher
            .compactMap { [weak self] in self?.handle(keyboardState: $0) }

        return .init(
            progressBarState: progress.eraseToAnyPublisher(),
            universalLink: universalLinkSubject.eraseToAnyPublisher(),
            recordUrl: recordUrlSubject.eraseToAnyPublisher(),
            dappAction: dappActionSubject.eraseToAnyPublisher(),
            keyboardAction: keyboardAction.eraseToAnyPublisher())
    }

    func shouldBeginPopInteraction() -> Bool {
        return !browserOnly
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

    private func handle(keyboardState: KeyboardChecker.KeyboardState) -> BrowserViewModel.KeyboardAction? {
        switch keyboardState.state {
        case .willShow:
            return .adjustBottomInset(height: keyboardState.endFrame.size.height)
        case .willHide:
            //If there's a external keyboard (or on simulator with software keyboard disabled):
            //    When text input starts. beginRect: size.height=0 endRect: size.height ~54. origin.y remains at ~812 (out of the screen)
            //    When text input ends. beginRect: size.height ~54 endRect: size.height = 0. origin.y remains at 812 (out of the screen)
            //Note the above. keyboardWillHide() is called for both when input starts and ends for external keyboard. Probably because the keyboard is hidden in both cases
            let beginRect = keyboardState.beginFrame
            let endRect = keyboardState.endFrame
            let isExternalKeyboard = beginRect.origin == endRect.origin && (beginRect.size.height == 0 || endRect.size.height == 0)
            let isEnteringEditModeWithExternalKeyboard: Bool
            if isExternalKeyboard {
                isEnteringEditModeWithExternalKeyboard = beginRect.size.height == 0 && endRect.size.height > 0
            } else {
                isEnteringEditModeWithExternalKeyboard = false
            }

            if !isExternalKeyboard || !isEnteringEditModeWithExternalKeyboard {
                //Must exit editing more explicitly (and update the nav bar buttons) because tapping on the web view can hide keyboard
                return .hideKeyboard
            }
            return nil
        case .frameChange, .didHide, .didShow:
            return nil
        }
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

    enum KeyboardAction {
        case hideKeyboard
        case adjustBottomInset(height: CGFloat)
    }

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
