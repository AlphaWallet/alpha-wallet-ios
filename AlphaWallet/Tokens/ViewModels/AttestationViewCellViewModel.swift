// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAttestation
import AlphaWalletFoundation
import Combine

struct AttestationViewCellViewModel {
    private let attestation: Attestation

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: R.string.localizable.attestationsEas(), attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var detailsAttributedString: NSAttributedString {
        var subtitle = ""
        for each in attestation.data {
            subtitle += "\(each.type.name): \(each.value.stringValue) "
        }
        return NSAttributedString(string: subtitle.trimmed, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    var iconImage: TokenImagePublisher {
        let programmaticallyGeneratedImage = UIImage.tokenSymbolBackgroundImage(backgroundColor: attestation.server.blockChainNameColor)
        return Just(TokenImage(image: ImageOrWebImageUrl.image(RawImage.loaded(image: programmaticallyGeneratedImage)), isFinal: true, overlayServerIcon: nil)).eraseToAnyPublisher()
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: attestation.server)
    }

    let accessoryType: UITableViewCell.AccessoryType = .none

    init(attestation: Attestation) {
        self.attestation = attestation
    }
}

extension AttestationViewCellViewModel: Hashable {
}
