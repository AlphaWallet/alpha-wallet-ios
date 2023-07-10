// Copyright © 2023 Stormbird PTE. LTD.

import AlphaWalletAddress

public protocol AssetDefinitionStoreProtocol: TokenScriptStatusResolver {
    var features: TokenScriptFeatures { get }

    subscript(contract: AlphaWallet.Address) -> String? { get }
    func isOfficial(contract: AlphaWallet.Address) -> Bool
    func isCanonicalized(contract: AlphaWallet.Address) -> Bool
    func getXmlHandler(for key: AlphaWallet.Address) -> PrivateXMLHandler?
    func set(xmlHandler: PrivateXMLHandler?, for key: AlphaWallet.Address)
    func getBaseXmlHandler(for key: String) -> PrivateXMLHandler?
    func setBaseXmlHandler(for key: String, baseXmlHandler: PrivateXMLHandler?)
    func baseTokenScriptFile(for tokenType: TokenType) -> XMLFile?
    func invalidateSignatureStatus(forContract contract: AlphaWallet.Address)

    var assetAttributeResolver: AssetAttributeResolver { get }
}
