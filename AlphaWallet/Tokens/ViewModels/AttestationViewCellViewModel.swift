// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAttestation
import AlphaWalletFoundation
import Combine

struct AttestationViewCellViewModel {
    private let attestation: Attestation
    private let assetDefinitionStore: AssetDefinitionStore

    //Cannot be computed properties because we need to include it in the hash for NSDiffableDataSourceSnapshot's computation when we go from no-TokenScript -> TokenScript or if the TokenScript file changes(add/deleted)
    let titleAttributedString: NSAttributedString
    let detailsAttributedString: NSAttributedString

    var iconImage: TokenImagePublisher {
        switch attestation.attestationType {
        case .smartLayerPass:
            return Just(TokenImage(image: ImageOrWebImageUrl.image(RawImage.loaded(image: R.image.smartLayerPass()!)), isFinal: true, overlayServerIcon: nil)).eraseToAnyPublisher()
        case .others:
            let programmaticallyGeneratedImage = UIImage.tokenSymbolBackgroundImage(backgroundColor: attestation.server.blockChainNameColor)
            return Just(TokenImage(image: ImageOrWebImageUrl.image(RawImage.loaded(image: programmaticallyGeneratedImage)), isFinal: true, overlayServerIcon: nil)).eraseToAnyPublisher()
        }
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: attestation.server)
    }

    let accessoryType: UITableViewCell.AccessoryType = .none

    init(attestation: Attestation, assetDefinitionStore: AssetDefinitionStore) {
        self.attestation = attestation
        self.assetDefinitionStore = assetDefinitionStore
        self.titleAttributedString = functional.computeTitleAttributedString(attestation: attestation, assetDefinitionStore: assetDefinitionStore)
        self.detailsAttributedString = functional.computeDetailsAttributedString(attestation: attestation, assetDefinitionStore: assetDefinitionStore)
    }
}

extension AttestationViewCellViewModel: Hashable {
}

extension AttestationViewCellViewModel {
    enum functional {}
}

fileprivate extension AttestationViewCellViewModel.functional {
    static func computeDetailsAttributedString(attestation: Attestation, assetDefinitionStore: AssetDefinitionStore) -> NSAttributedString {
        let data: [Attestation.TypeValuePair]
        if let xmlHandler = assetDefinitionStore.xmlHandler(forAttestation: attestation) {
            data = xmlHandler.resolveAttestationAttributes(forAttestation: attestation)
        } else {
            data = attestation.data
        }
        var subtitle = ""
        for each in data {
            subtitle += "\(each.type.name): \(each.value.stringValue) "
        }
        return NSAttributedString(string: subtitle.trimmed, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    static func computeTitleAttributedString(attestation: Attestation, assetDefinitionStore: AssetDefinitionStore) -> NSAttributedString {
        let name = assetDefinitionStore.xmlHandler(forAttestation: attestation)?.getAttestationName() ?? attestation.name
        return NSAttributedString(string: name, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .font: Screen.TokenCard.Font.title
        ])
    }
}