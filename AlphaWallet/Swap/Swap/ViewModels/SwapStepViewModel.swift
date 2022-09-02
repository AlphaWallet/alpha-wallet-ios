//
//  SwapFeeProviderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.03.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct InfoButtonViewModel {
    let isHidden: Bool
}

extension SwapStepsViewModel {

    struct SwapStepViewModel {
        private let swapStep: SwapStep

        var backgroundColor: UIColor = R.color.alabaster()!

        var toolAttributedString: NSAttributedString {
            NSAttributedString(string: "\(swapStep.tool.uppercased()) Contract", attributes: [
                .font: Fonts.bold(size: 15),
                .foregroundColor: R.color.dove()!
            ])
        }
        var descriptionAttributedString: NSAttributedString {
            NSAttributedString(string: "Single transaction including:", attributes: [
                .font: Fonts.regular(size: 15),
                .foregroundColor: R.color.dove()!
            ])
        }

        let subSteps: [SwapSubStepViewModel]

        var infoButtonViewModel: AnyPublisher<InfoButtonViewModel, Never> {
            return .just(.init(isHidden: true))
        }

        init(swapStep: SwapStep) {
            self.swapStep = swapStep
            subSteps = swapStep.subSteps.enumerated().map { SwapSubStepViewModel(subStep: $1, index: $0) }
        }
    }

    struct SwapSubStepViewModel {
        private let subStep: SwapSubStep
        private let index: Int
        var backgroundColor: UIColor = R.color.alabaster()!

        var descriptionAttributedString: NSAttributedString {
            let amount = EtherNumberFormatter.short.string(from: subStep.amount, decimals: subStep.token.decimals)
            let description = "\(subStep.type.capitalized) to \(amount) \(subStep.token.symbol) via \(subStep.tool)"
            return NSAttributedString(string: "\(index + 1). \(description)", attributes: [
                .font: Fonts.regular(size: 15),
                .foregroundColor: R.color.dove()!
            ])
        }

        init(subStep: SwapSubStep, index: Int) {
            self.subStep = subStep
            self.index = index
        }
    }
}
