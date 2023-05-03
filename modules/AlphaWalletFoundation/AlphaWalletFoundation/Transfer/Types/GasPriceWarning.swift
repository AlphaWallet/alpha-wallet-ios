//
//  GasPriceWarning.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.05.2022.
//

import Foundation

extension TransactionConfigurator {
    public struct GasPriceWarning: Warning {
        public let server: RPCServer
        public let warning: WarningType

        public init(server: RPCServer, warning: WarningType) {
            self.server = server
            self.warning = warning
        }

        public enum WarningType {
            case tooHighCustomGasPrice
            case networkCongested
            case tooLowCustomGasPrice
        }
    }
}
