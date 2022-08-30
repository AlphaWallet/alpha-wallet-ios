//
//  ButtonsBarStyle.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 9/2/22.
//

import UIKit

enum ButtonsBarStyle {
    enum Colors {
        static var primaryBackgroundActive: UIColor {
            return R.color.cod()!
        }
        static var primaryBackgroundInactive: UIColor {
            return R.color.mike()!
        }
        static var primaryTextActive: UIColor {
            return R.color.white()!
        }
        static var primaryTextInactive: UIColor {
            return R.color.white()!
        }
        static var primaryBorderActive: UIColor {
            return R.color.cod()!
        }
        static var primaryBorderInactive: UIColor {
            return R.color.mike()!
        }
        static var primaryHighlightedBackground: UIColor {
            return R.color.black()!
        }
        static var secondaryBackgroundActive: UIColor {
            return R.color.white()!
        }
        static var secondaryBackgroundInactive: UIColor {
            return R.color.white()!
        }
        static var secondaryTextActive: UIColor {
            return R.color.cod()!
        }
        static var secondaryTextInactive: UIColor {
            return R.color.alto()!
        }
        static var secondaryBorderActive: UIColor {
            return R.color.cod()!
        }
        static var secondaryBorderInactive: UIColor {
            return R.color.alto()!
        }
        static var secondaryHighlightedBackground: UIColor {
            return R.color.concrete()!
        }
    }
}

