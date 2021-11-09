//
//  RequestHandlerToAvoidMemoryLeak.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import WalletConnectSwift

protocol WalletConnectV1ServerRequestHandlerDelegate: AnyObject {
    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, request: WalletConnectV1Request)
    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, canHandle request: WalletConnectV1Request) -> Bool
}

//NOTE: if we manually pass `self` link to WalletConnect server it causes memory leak and object doesn't get deleted.
class RequestHandlerToAvoidMemoryLeak {
    weak var delegate: WalletConnectV1ServerRequestHandlerDelegate?
}

extension RequestHandlerToAvoidMemoryLeak: RequestHandler {

    func canHandle(request: WalletConnectV1Request) -> Bool {
        guard let delegate = delegate else { return false }

        return delegate.handler(self, canHandle: request)
    }

    func handle(request: WalletConnectV1Request) {
        delegate?.handler(self, request: request)
    }
}
