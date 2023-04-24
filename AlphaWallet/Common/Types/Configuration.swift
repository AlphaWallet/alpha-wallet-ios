//
//  Configuration.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 30/5/22.
//

import UIKit

fileprivate func colorFrom(trait: UITraitCollection, lightColor: UIColor, darkColor: UIColor) -> UIColor {
    switch trait.userInterfaceStyle {
    case .unspecified, .light:
        return lightColor
    case .dark:
        return darkColor
    @unknown default:
        return lightColor
    }
}

// swiftlint:disable type_body_length

struct Configuration {
    struct Color {
        struct Semantic {
            static let walletSummaryApprecationForeground = UIColor.gray
            static let transitionButtonShrinkBorder = UIColor.lightGray
            static let borderClear = UIColor.clear
            static let backgroundClear = UIColor.clear
            static let defaultViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let defaultForegroundText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let defaultInverseText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }
            static let defaultSubtitleText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dove()!, darkColor: R.color.dusty()!)
            }
            static let defaultTitleText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: .black, darkColor: .white)
            }
            static let defaultHeadlineText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }
            static let indicator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }
            static let loading = R.color.loadingBackground()!
            static let loadingIndicatorBorder = UIColor(red: 237, green: 237, blue: 237)
            static let loadingIndicatorBackground = UIColor.white
            static let circularLoadingIndicatorLine = UIColor.red
            static let activityStateViewPendingLoadingIndicatorViewBackground = UIColor.white
            static let backgroundLine = UIColor.lightGray
            static let checkmark = UIColor.red
            static let backButtonText = UIColor.clear
            static let dappsIconShadow = UIColor.black
            static let browserHistoryCellName = UIColor(red: 77, green: 77, blue: 77)
            static let myDappCellName = UIColor(red: 77, green: 77, blue: 77)
            static let promptBackupWalletAfterWalletCreationViewBackupButtonBackground = UIColor(red: 119, green: 56, blue: 50)
            static let promptBackupWalletAfterReceivingNativeCryptoCurrencyViewBackupButtonBackground = UIColor(red: 65, green: 71, blue: 89)
            static let promptBackupWalletAfterIntervalViewBackupButtonBackground = UIColor(red: 65, green: 71, blue: 89)
            static let promptBackupWalletAfterExceedingThresholdViewBackupButtonBackground = UIColor(red: 119, green: 56, blue: 50)
            static let NFTAssetViewPreviewViewContentBackgroundColor = UIColor(red: 247, green: 197, blue: 196)
            static let nonFungibleRowViewContentBackgroundColor = UIColor(red: 247, green: 197, blue: 196)
            static let openSeaNonFungibleTokenCardRowBigImageBackgroundColor = UIColor(red: 247, green: 197, blue: 196)
            static let importSeedText = UIColor(red: 116, green: 116, blue: 116)
            static let seedPhraseCellBackground = UIColor(red: 234, green: 234, blue: 234)
            static let seedPhraseCellSelectedBackground = UIColor(red: 249, green: 249, blue: 249)
            static let seedPhraseCellText = UIColor(red: 42, green: 42, blue: 42)
            static let seedPhraseCellSelectedText = UIColor(red: 255, green: 255, blue: 255)
            static let seedPhraseCellSequence = UIColor(red: 200, green: 200, blue: 200)
            static let contactUsBannerBackground = UIColor(red: 249, green: 208, blue: 33)
            static let buttonUrlText = UIColor(red: 84, green: 84, blue: 84)
            static let buttonBorderlessBorder = UIColor.clear
            static let buttonBackgroundSystem = UIColor.clear
            static let buttonBackgroundHighlighted = UIColor.clear
            static let blockChainHeco = UIColor(hex: "1253FC")
            static let blockChainCronosMainnet = UIColor(hex: "#002D74")
            static let blockChainKlaytnCypress = UIColor(hex: "FE3300")
            static let blockChainKlaytnBaobabTestnet = UIColor(hex: "313557")
            static let blockChainIoTeX = UIColor(hex: "00D4D5")
            static let blockChainIoTeXTestnet = UIColor(hex: "00D4D5")
            static let blockChainMain = UIColor(red: 41, green: 134, blue: 175)
            static let blockChainClassic = UIColor(red: 55, green: 137, blue: 55)
            static let blockChainCallisto = UIColor(red: 88, green: 56, blue: 163)
            static let blockChainPoa = UIColor(red: 88, green: 56, blue: 163)
            static let blockChainGoerli = UIColor(red: 187, green: 174, blue: 154)
            static let blockChainXDai = UIColor(red: 253, green: 176, blue: 61)
            static let blockChainBinanceSmartChain = UIColor(red: 255, green: 211, blue: 0)
            static let blockChainFantom = UIColor.red
            static let blockChainFantomTestnet = UIColor.red
            static let blockChainAvalanche = UIColor.red
            static let blockChainAvalancheTestnet = UIColor.red
            static let blockChainPolygon = UIColor(red: 130, green: 71, blue: 229)
            static let blockChainOptimistic = UIColor.red
            static let blockChainCronosTestnet = UIColor.red
            static let blockChainArbitrum = UIColor.red
            static let blockChainPalm = UIColor.red
            static let blockChainPalmTestnet = UIColor.red
            static let blockChainOptimismGoerli = UIColor.red
            static let blockChainArbitrumGoerli = UIColor.red
            static let blockChainCustom = UIColor.red
            static let blockChainOkx = UIColor.black
            static let blockChainSepolia = UIColor(hex: "87ff65")
            
            static let openSeaNonFungibleTokenCardRowIconText = UIColor(red: 192, green: 192, blue: 192)
            static let openSeaNonFungibleTokenCardRowIdText = UIColor(red: 155, green: 155, blue: 155)
            static let openSeaNonFungibleTokenCardRowGenerationText = UIColor(red: 155, green: 155, blue: 155)
            static let openSeaNonFungibleTokenCardRowCooldownText = UIColor(red: 155, green: 155, blue: 155)

            static let alternativeText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: .darkGray, darkColor: .lightGray)
            }

            static let defaultErrorText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.danger()!, darkColor: R.color.danger()!)
            }

            static let defaultAttributedString = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

            static let disabledActionButton = UIColor(hex: "d7ebc8")
            static let specialButton = R.color.concrete()!

            static let qrCodeRectBorders = UIColor(red: 216, green: 216, blue: 216)
            static let defaultButtonBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let inverseDefaultButtonBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cod()!, darkColor: R.color.white()!)
            }
            static let primaryButtonBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cod()!, darkColor: R.color.alabaster()!)
            }
            static let primaryButtonHighlightedBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.concrete()!)
            }
            static let primaryButtonBackgroundInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.mine()!)
            }
            static let primaryButtonBorderInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.mine()!)
            }
            static let primaryButtonTextActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }
            static let primaryButtonTextInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }
            static let primaryButtonBorderActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cod()!, darkColor: R.color.alabaster()!)
            }

            static let secondaryButtonBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }
            static let secondaryButtonHighlightedBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.concrete()!, darkColor: R.color.black()!)
            }
            static let secondaryButtonBackgroundInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.dusty()!)
            }
            static let secondaryButtonBorderInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.dusty()!)
            }
            static let secondaryButtonTextActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let secondaryButtonTextInactive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let secondaryButtonBorderActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.dusty()!)
            }

            static let periodButtonSelectedText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let periodButtonSelectedBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: .darkGray, darkColor: .lightGray)
            }
            static let periodButtonNormalText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cod()!, darkColor: R.color.white()!)
            }
            static let periodButtonNormalBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let defaultButtonBorder = R.color.alabaster()!
            static let actionButtonBackground = UIColor(red: 105, green: 200, blue: 0)
            static let actionButtonShadow = UIColor.clear
            static let cancelButtonTitle = R.color.danger()!
            static let deleteButtonTitle = R.color.danger()!
            static let defaultNote = R.color.danger()!

            static let labelTextActive = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }

            static let tableViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let tableViewCellBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let tableViewCellPrimaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let tableViewCellSecondaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dove()!, darkColor: R.color.dusty()!)
            }
            static let placeholderText = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dusty()!, darkColor: R.color.porcelain()!)
            }
            static let tableViewAccessory = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let tableViewAccessoryBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }
            static let tableViewHeaderBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }
            static let tableViewHeaderPrimaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }

            static let tableViewSeparator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let tableViewSpecialBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.solitude()!, darkColor: R.color.mine()!)
            }

            static let refreshControl = UIColor { trait in
                return colorFrom(trait: trait, lightColor: .black, darkColor: .white)
            }
            
            static let collectionViewCellBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }
            static let searchBarTint = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }

            static let navigationBarBackgroundColor = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }

            static let navigationBarSeparator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let navigationBarPrimaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }

            static let navigationBarButtonItemTint = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }

            static let popupBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let popupPrimaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }

            static let popupSecondaryFont = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mine()!, darkColor: R.color.white()!)
            }

            static let popupSeparator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let popupSwipeIndicator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!.withAlphaComponent(0.2), darkColor: R.color.white()!.withAlphaComponent(0.2))
            }

            static let scrollableSegmentedControlLineColor = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let scrollableSegmentedControllerHighlightColor = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

            static let scrollableSegmentedControllerBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }

            static let scrollableSegmentedControllerNonHighlightColor = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dove()!, darkColor: R.color.dusty()!)
            }

            static let searchBarBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }

            static let searchbarPlaceholder = UIColor.lightGray

            static let seedText = UIColor.lightGray
            
            static let tabBarBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.cod()!)
            }

            static let tabBarTint = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

            static let tabBarUnselected = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.dove()!, darkColor: R.color.dusty()!)
            }

            static let tabBarSeparator = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mercury()!, darkColor: R.color.venus()!)
            }

            static let collectionViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.shark()!)
            }

            static let overlayBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!.withAlphaComponent(0.3), darkColor: R.color.white()!.withAlphaComponent(0.3))
            }

            static let dialogBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.black()!)
            }

            static let textFieldIcon = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let textFieldContrastText = UIColor(red: 86, green: 153, blue: 8)
            
            static let textFieldBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }
            static let textFieldPasswordTint = UIColor(red: 111, green: 111, blue: 111)
            static let configureTransactionBackground = UIColor(red: 255, green: 235, blue: 234)
            static let configureTransactionBorder = UIColor(red: 252, green: 187, blue: 183)
            static let promptBackupWalletAfterWalletCreationViewBackground = UIColor(red: 183, green: 80, blue: 70)
            static let promptBackupWalletAfterReceivingNativeCryptoCurrencyViewBackground = UIColor(red: 97, green: 103, blue: 123)
            static let promptBackupWalletAfterIntervalViewBackground = UIColor(red: 97, green: 103, blue: 123)
            static let promptBackupWalletAfterExceedingThresholdViewBackground = UIColor(red: 183, green: 80, blue: 70)
            static let tokenHistoryChartViewGrid = UIColor(red: 220, green: 220, blue: 220)
            static let textViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let containerTableViewCellBackground = UIColor.clear
            static let numberStepperButtonsBackground = UIColor.clear
            static let numberStepperLabelBackground = UIColor.clear
            static let addressTextFieldPasteButtonBackground = UIColor.clear
            static let addressTextFieldClearButtonBackground = UIColor.clear
            static let addressTextFieldControlsContainerBackground = UIColor.clear
            static let addressTextFieldScanQRCodeButtonBackground = UIColor.clear
            static let addressTextFieldTargetAddressRightViewBackground = UIColor.clear
            
            static let shadow = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }

            static let sendingState = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.solitude()!, darkColor: R.color.luckyPoint()!)
            }

            static let pendingState = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.cheese()!, darkColor: R.color.ocean()!)
            }
            static let roundButtonBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.mike()!, darkColor: R.color.mine()!)
            }

            static let textViewFailed = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.silver()!, darkColor: R.color.porcelain()!)
            }
            static let progressDialogBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.alabaster()!, darkColor: R.color.venus()!)
            }

            static let appTint = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.azure()!, darkColor: R.color.dodge()!)
            }

            static let dangerBackground = R.color.danger()!
            static let appreciation = UIColor(red: 117, green: 185, blue: 67)
            static let depreciation = R.color.danger()!
            static let pass = appreciation
            static let fail = depreciation

            static let border = UIColor(red: 194, green: 194, blue: 194)
            static let textFieldStatus = Configuration.Color.Semantic.defaultErrorText
            static let icon = Configuration.Color.Semantic.appTint
            static let secondary = UIColor(red: 155, green: 155, blue: 155)
            static let textFieldShadowWhileEditing = Configuration.Color.Semantic.appTint
            static let placeholder = UIColor(hex: "919191")
            static let ensText = UIColor(red: 117, green: 185, blue: 67)
            static let searchTextFieldBackground = UIColor(red: 243, green: 244, blue: 245)
            static let headerViewBackground = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.white()!, darkColor: R.color.venus()!)
            }
            static let defaultIcon = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
            static let secureIcon = UIColor { trait in
                return colorFrom(trait: trait, lightColor: R.color.black()!, darkColor: R.color.white()!)
            }
        }
    }
}

// swiftlint:enable type_body_length

extension Configuration {
    enum Font {
        static let text = Fonts.regular(size: ScreenChecker.size(big: 18, medium: 18, small: 14))
        static let label = Fonts.bold(size: 13)
        static let textFieldTitle = Fonts.regular(size: 13)
        static let textFieldStatus = Fonts.bold(size: 13)
        static let textField = Fonts.regular(size: ScreenChecker.size(big: 17, medium: 17, small: 14))
        static let accessory = Fonts.bold(size: ScreenChecker.size(big: 17, medium: 17, small: 14))
        static let amountTextField = Fonts.regular(size: ScreenChecker.size(big: 36, medium: 36, small: 26))
    }
}

class UIKitFactory {

    static func defaultView(autoResizingMarkIntoConstraints: Bool = false) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = autoResizingMarkIntoConstraints
        return decorateAsDefaultView(view)
    }

    @discardableResult static func decorateAsDefaultView(_ view: UIView) -> UIView {
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        return view
    }

    @discardableResult static func decorateAsDefaultView(_ views: [UIView]) -> [UIView] {
        return views.map { decorateAsDefaultView($0) }
    } 
}
