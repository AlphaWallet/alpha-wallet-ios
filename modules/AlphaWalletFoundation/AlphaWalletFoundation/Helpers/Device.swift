//
//  Type.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.01.2022.
//

import UIKit

/// Used to get information about current, device, screen or iOS version.
///
/// **Device version information**
///
/// To get current device type use:
///
/// ```
/// let device = Device.type
///
/// switch device {
/// case .phone: print("iPhone")
/// case .pad: print("iPad")
/// case .pod: print("iPod")
/// case .simulator: print("Simulator")
/// default: print("Unknown")
/// }
/// ```
///
/// You can check exact device version with next code. All possible values of `version` could be
/// found in Version enum, Version.swift file.
///
/// ```
/// let version = Device.version
///
/// switch version {
/// case .phone5S: print("iPhone 5S")
/// case .padPro: print("iPad Pro")
/// default: print("Other device")
/// }
/// ```
///
/// There are few properties that detect global device type not depending is it simulator or not.
///
/// ```
/// Device.isPhone     // true for iPhones
/// Device.isPhoneX    // true for iPhoneX
/// Device.isPad       // true for iPads
/// Device.isPadPro    // true for iPadPros
/// ```
///
/// Simulator detecting is easy
///
/// ```
/// Device.isSimulator // true for Simulators
/// ```
///
/// **Device screen parameters**
///
/// Detecting screen size can be detected with next code. All possible values could be
/// found in Screen enum, Screen.swift
///
/// ```
/// let screen = Device.screen
///
/// switch screen {
/// case .inches_3_5:  print("3.5 inches")
/// case .inches_4_0:  print("4.0 inches")
/// case .inches_4_7:  print("4.7 inches")
/// case .inches_5_5:  print("5.5 inches")
/// case .inches_7_9:  print("7.9 inches")
/// case .inches_9_7:  print("9.7 inches")
/// case .inches_12_9: print("12.9 inches")
/// default:           print("Other display")
/// }
/// ```
///
/// **Detecting screen family**
///
/// Often it's required to bing different parameters for specific screen resolution.
/// There are 2 methods that will help you to detect what parameter to use. But
/// first of all let me introduce ScreenFamily.
///
/// This is enum that breaks all possible screen resolutions into 3 groups:
/// - ScreenFamily.*small*:        All iPhones/iPods without iPhone 6Plus
/// - ScreenFamily.*medium*:       iPhone 6Plus and iPad Mini
/// - ScreenFamily.*big*:          iPad and iPad Pro
///
/// You can detect screen family by:
///
/// ```
/// let family = Device.screen.family
/// ```
///
/// And now back to methods. To assign different values for iPhone and iPad devices you can use this method:
///
/// ```
/// let size = Device.size(13, pad: 15)
/// let font = UIFont(name: "Arial", size: CGFloat(size))
/// ```
///
/// On iPhones your font size will be 13.0, on iPads 15.0
///
/// Another method based on ScreenFamily:
///
/// ```
/// let otherSize = Device.size(12, medium: 14, big: 15)
/// let otherFont = UIFont(name: "Arial", size: CGFloat(otherSize))
/// ```
///
/// In this case for small screens your font will be 12.0, for medium 14.0 and for big 15.0 inches
///
/// *Important notice:* By default if screen family can not be detected `size` method will
/// assign small value.
///
/// **Screen scale**
///
/// Detecting screen scale is easy too:
///
/// ```
/// let scale == Device.scale
///
/// switch scale {
/// case .x1: print("Not retina")
/// case .x2: print("Good")
/// case .x3: print("Your device rocks!")
/// }
/// ```
///
/// Also there is a property to detect if it's retina display:
///
/// ```
/// Device.isRetina // true if device screen scale greater than 1.0
/// ```
///
/// **Interface orientation**
///
/// There are two properties that will help you to know current orientation:
///
/// ```
/// Device.isLandscape // true if landscape
/// Device.isPortrait  // true if portrait
/// ```
///
/// To detect slide over layout on iPads just call:
///
/// ```
/// Device.isSlideOverLayout // true if iPad is in multitasking / slide over layout
/// ```
///
/// **Detecting iOS version**
///
/// You can detect iOS version in runtime. There are 5 different methods that will help you to
/// detect it:
///
/// ```
/// Device.osVersion                               // Current version as a `OSVersion` model
///
/// Device.osVersion == Device.os9                 // true if iOS 9.0
/// Device.osVersion >= Device.os9                 // true if iOS >= 9.0
/// Device.osVersion < Device.os11                 // true if iOS < 11.0
/// etc.
/// ```
///
/// There are next constants representating Main iOS versions:
///
/// ```
/// Device.os8
/// Device.os9
/// Device.os10
/// Device.os11
/// Device.os12
/// Device.os13
/// Device.os14
/// ```

public extension AlphaWallet {
    enum Device {}
}

/// Detecting device state
extension AlphaWallet.Device {
    /// Return `true` for landscape interface orientation
    static public var isLandscape: Bool {
        let statusBarOrientation: UIInterfaceOrientation
        if let currentWindowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            statusBarOrientation = currentWindowScene.interfaceOrientation
        } else {
            statusBarOrientation = .portrait
        }

        return statusBarOrientation == .landscapeLeft || statusBarOrientation == .landscapeRight
    }

    /// Return `true` for portrait interface orientation
    static public var isPortrait: Bool {
        return !isLandscape
    }
}

/// Battery state
extension AlphaWallet.Device {
    public struct Battery {
        /// Return battery state
        static public var state: UIDevice.BatteryState {
            enableBatteryMonitoringIfNecessary()
            return UIDevice.current.batteryState
        }

        /// Battery level from 0.0 to 1.0. Will enable monitoring if not enabled.
        static public var level: Float {
            enableBatteryMonitoringIfNecessary()
            return UIDevice.current.batteryLevel
        }

        static private func enableBatteryMonitoringIfNecessary() {
            guard !UIDevice.current.isBatteryMonitoringEnabled else { return }
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
    }
}

/// Multitasking / Slide Over for iPad
public extension AlphaWallet.Device {
    /// Return `true` is iPad is in multitasking / slide over layout mode
    static var isSlideOverLayout: Bool {
        guard AlphaWallet.Device.isPad else { return false }
        guard let rootWindow = UIApplication.shared.delegate?.window, let window = rootWindow else { return false }
        return !window.frame.equalTo(window.screen.bounds)
    }
}

public extension AlphaWallet.Device {
    /// Device types
    ///
    /// - Parameter phone:
    /// - Parameter pad:
    /// - Parameter pod:
    /// - Parameter simulator:
    /// - Parameter unknown
    enum DeviceType: String {
        case phone
        case pad
        case pod
        case simulator
        case unknown
    }

    /// Exact device version
    enum Version: String {
        case phone4
        case phone4S
        case phone5
        case phone5C
        case phone5S
        case phone6
        case phone6Plus
        case phone6S
        case phone6SPlus
        case phoneSE
        case phone7
        case phone7Plus
        case phone8
        case phone8Plus
        case phoneX
        case phoneXS
        case phoneXSMax
        case phoneXR
        case phone11
        case phone11Pro
        case phone11ProMax
        case phoneSE2
        case phone12mini
        case phone12
        case phone12Pro
        case phone12ProMax
        case phoneSE3
        case phone13mini
        case phone13
        case phone13Pro
        case phone13ProMax
        case phone14
        case phone14Plus
        case phone14Pro
        case phone14ProMax
        case pad1
        case pad2
        case padMini
        case pad3
        case pad4
        case pad5
        case pad6
        case pad7
        case pad8
        case pad9
        case pad10
        case padAir
        case padMini2
        case padAir2
        case padMini3
        case padMini4
        case padMini5
        case padAir3
        case padAir4
        case padAir5
        case padPro9_7
        case padPro12_9
        case padPro12_9_2th
        case padPro10_5
        case padPro11
        case padPro12_9_3th
        case padPro11_2th
        case padPro11_3th
        case padPro11_4th
        case padPro12_9_4th
        case padPro12_9_5th
        case padPro12_9_6th
        case podTouch1
        case podTouch2
        case podTouch3
        case podTouch4
        case podTouch5
        case podTouch6
        case podTouch7
        case simulator

        case unknown

        /// Return device screen
        ///
        /// - seealso: Screen
        public var screen: Screen {
            switch self {
            case .podTouch1, .podTouch2, .podTouch3, .podTouch4, .phone4, .phone4S: return .inches_3_5
            case .podTouch5, .podTouch6, .podTouch7, .phone5, .phone5C, .phone5S, .phoneSE: return .inches_4_0
            case .phone6, .phone6S, .phone7, .phone8: return .inches_4_7
            case .phone6Plus, .phone6SPlus, .phone7Plus, .phone8Plus: return .inches_5_5
            case .phoneX, .phoneXS: return .inches_5_8
            case .phoneXR: return .inches_6_1
            case .phoneXSMax: return .inches_6_5
            case .phone11: return .inches_6_1
            case .phone11Pro: return .inches_5_8
            case .phone11ProMax: return .inches_6_5
            case .phoneSE2, .phoneSE3: return .inches_4_7
            case .phone12mini, .phone12, .phone12Pro: return .inches_6_1
            case .phone12ProMax, .phone14Plus, .phone14ProMax: return .inches_6_7
            case .phone13mini: return .inches_5_4
            case .phone13, .phone13Pro, .phone14, .phone14Pro: return .inches_6_1
            case .phone13ProMax: return .inches_6_7
            case .padMini, .padMini2, .padMini3, .padMini4, .padMini5: return .inches_7_9
            case .pad1, .pad2, .pad3, .pad4, .pad5, .pad6, .padAir, .padAir2, .padPro9_7: return .inches_9_7
            case .pad7, .pad8, .pad9: return .inches_10_2
            case .pad10, .padAir4, .padAir5: return .inches_10_9
            case .padPro12_9, .padPro12_9_2th, .padPro12_9_3th, .padPro12_9_4th, .padPro12_9_5th, .padPro12_9_6th: return .inches_12_9
            case .padPro10_5, .padAir3: return .inches_10_5
            case .padPro11, .padPro11_2th, .padPro11_3th, .padPro11_4th: return .inches_11
            case .unknown, .simulator: return .unknown
            }
        }
    }
}
/// Used to determinate device type
extension AlphaWallet.Device {

    /// Return raw device version code string or empty string if any problem appears.
    static public var versionCode: String {
        var systemInfo = utsname()
        uname(&systemInfo)

        if  let info = NSString(bytes: &systemInfo.machine, length: Int(_SYS_NAMELEN), encoding: String.Encoding.ascii.rawValue),
            let code = String(validatingUTF8: info.utf8String!) {
            return code
        }

        return ""
    }

    /// Return device type
    ///
    /// - seealso: Type
    static public var type: AlphaWallet.Device.DeviceType {
        let versionCode = AlphaWallet.Device.versionCode
        if versionCode.starts(with: "iPhone") {
            return .phone
        } else if versionCode.starts(with: "iPad") {
            return .pad
        } else if versionCode.starts(with: "iPod") {
            return .pod
        } else if TARGET_OS_SIMULATOR != 0 {
            //Original check was: `versionCode == "i386" || versionCode == "x86_64" || versionCode == "arm64"`. But we want this to have no false-negatives since wrongly identifying as simulator can cause certain functionality to be unlocked for production/appstore users
            return .simulator
        }
        return .unknown
    }

    /// Return `true` for iPad-s
    static public var isPad: Bool {
        return (UIDevice.current.userInterfaceIdiom == .pad )
    }

    /// Return `true` for iPhone-s
    static public var isPhone: Bool {
        return !isPad
    }

    /// Return `true` for iPhoneX
    @available(*, deprecated, message: ".isPhoneX deprecated. Use .isNotched instead")
    static public var isPhoneX: Bool {
        return isPhone && screen == .inches_5_8
    }

    /// Return `true` for iPadPro
    static public var isPadPro: Bool {
        return isPad && screen == .inches_12_9
    }

    /// Return `true` for Simulator
    static public var isSimulator: Bool {
        return type == .simulator
    }

    /// Return `true` if device has a notch
    static public var isNotched: Bool {
        return isPhone && (screen == .inches_5_8 || screen == .inches_6_1 || screen == .inches_6_5 || screen == .inches_5_4 || screen == .inches_5_5 || screen == .inches_6_7)
    }

    // MARK: Version
    static public var version: Version {
        switch AlphaWallet.Device.versionCode {
        // Phones
        case "iPhone3,1", "iPhone3,2", "iPhone3,3": return .phone4
        case "iPhone4,1", "iPhone4,2", "iPhone4,3": return .phone4S
        case "iPhone5,1", "iPhone5,2": return .phone5
        case "iPhone5,3", "iPhone5,4": return .phone5C
        case "iPhone6,1", "iPhone6,2": return .phone5S
        case "iPhone7,2": return .phone6
        case "iPhone7,1": return .phone6Plus
        case "iPhone8,1": return .phone6S
        case "iPhone8,2": return .phone6SPlus
        case "iPhone8,4": return .phoneSE
        case "iPhone9,1", "iPhone9,3": return .phone7
        case "iPhone9,2", "iPhone9,4": return .phone7Plus
        case "iPhone10,1", "iPhone10,4": return .phone8
        case "iPhone10,2", "iPhone10,5": return .phone8Plus
        case "iPhone10,3", "iPhone10,6": return .phoneX
        case "iPhone11,2": return .phoneXS
        case "iPhone11,4", "iPhone11,6": return .phoneXSMax
        case "iPhone11,8": return .phoneXR
        case "iPhone12,1": return .phone11
        case "iPhone12,3": return .phone11Pro
        case "iPhone12,5": return .phone11ProMax
        case "iPhone12,8": return .phoneSE2
        case "iPhone13,1": return .phone12mini
        case "iPhone13,2": return .phone12
        case "iPhone13,3": return .phone12Pro
        case "iPhone13,4": return .phone12ProMax
        case "iPhone14,4": return .phone12mini
        case "iPhone14,5": return .phone13
        case "iPhone14,2": return .phone13Pro
        case "iPhone14,3": return .phone12ProMax
        case "iPhone14,6": return .phoneSE3
        case "iPhone14,7": return .phone14
        case "iPhone14,8": return .phone14Plus
        case "iPhone15,2": return .phone14Pro
        case "iPhone15,3": return .phone14ProMax

        // Pads
        case "iPad1,1": return .pad1
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4": return .pad2
        case "iPad3,1", "iPad3,2", "iPad3,3": return .pad3
        case "iPad3,4", "iPad3,5", "iPad3,6": return .pad4
        case "iPad6,11", "iPad6,12": return .pad5
        case "iPad4,1", "iPad4,2", "iPad4,3": return .padAir
        case "iPad5,3", "iPad5,4": return .padAir2
        case "iPad2,5", "iPad2,6", "iPad2,7": return .padMini
        case "iPad4,4", "iPad4,5", "iPad4,6": return .padMini2
        case "iPad4,7", "iPad4,8", "iPad4,9": return .padMini3
        case "iPad5,1", "iPad5,2": return .padMini4
        case "iPad6,3", "iPad6,4": return .padPro9_7
        case "iPad6,7", "iPad6,8": return .padPro12_9
        case "iPad7,1", "iPad7,2": return .padPro12_9_2th
        case "iPad7,3", "iPad7,4": return .padPro10_5
        case "iPad7,5", "iPad7,6": return .pad6
        case "iPad7,11", "iPad7,12": return .pad7
        case "iPad11,6", "iPad11,7": return .pad8
        case "iPad12,1", "iPad12,2": return .pad9
        case "iPad13,18", "iPad13,19": return .pad10
        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": return .padPro11
        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": return .padPro12_9_3th
        case "iPad8,9", "iPad8,10": return .padPro11_2th
        case "iPad8,11", "iPad8,12": return .padPro12_9_4th
        case "iPad11,1", "iPad11,2": return .padMini5
        case "iPad11,3", "iPad11,4": return  .padAir3
        case "iPad13,1", "iPad13,2": return .padAir4
        case "iPad13,16", "iPad13,17": return .padAir5
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": return .padPro12_9_5th
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": return .padPro11_3th
        case "iPad14,3-A", "iPad14,3-B", "iPad14,4-A", "iPad14,4-B": return .padPro11_4th
        case "iPad14,5-A", "iPad14,5-B", "iPad14,6-A", "iPad14,6-B": return .padPro12_9_6th

        // Pods
        case "iPod1,1": return .podTouch1
        case "iPod2,1": return .podTouch2
        case "iPod3,1": return .podTouch3
        case "iPod4,1": return .podTouch4
        case "iPod5,1": return .podTouch5
        case "iPod7,1": return .podTouch6
        case "iPod9,1": return .podTouch7

        // Simulator
        case "i386", "x86_64", "arm64": return .simulator

        // Unknown
        default: return .unknown
        }
    }
}

extension AlphaWallet.Device.Version {
   public var readableName: String {
        switch self {
        case .phone4: return "iPhone 4"
        case .phone4S:  return "iPhone 4s"
        case .phone5:  return "iPhone 5"
        case .phone5C:  return "iPhone 5C"
        case .phone5S: return "iPhone 5s"
        case .phone6: return "iPhone 6"
        case .phone6Plus: return "iPhone 6 Plus"
        case .phone6S:  return "iPhone 6s"
        case .phone6SPlus: return "iPhone 6s Plus"
        case .phoneSE:  return "iPhone SE"
        case .phone7: return "iPhone 7"
        case .phone7Plus: return "iPhone 7 Plus"
        case .phone8: return "iPhone 8"
        case .phone8Plus: return "iPhone 8 Plus"
        case .phoneX: return "iPhone X"
        case .phoneXS: return "iPhone Xs"
        case .phoneXSMax: return "iPhone Xs Max"
        case .phoneXR: return "iPhone XR"
        case .phone11: return "iPhone 11"
        case .phone11Pro: return "iPhone 11 Pro"
        case .phone11ProMax:  return "iPhone 11 Pro Max"
        case .phoneSE2: return "iPhone SE 2nd Gen"
        case .phoneSE3: return "iPhone SE 3rd Gen"

        case .pad1: return "iPad"
        case .pad2: return "2nd Gen iPad"
        case .padMini:  return "iPad Mini"
        case .pad3: return "3rd Gen iPad"
        case .pad4: return "4th Gen iPad"
        case .pad5: return "iPad (2017)"
        case .pad6: return "iPad 6th Gen"
        case .pad7: return "iPad 7th Gen 10.2-inch"
        case .padAir: return "iPad Air"
        case .padMini2: return "iPad mini Retina"
        case .padAir2:  return "iPad Air 2"
        case .padMini3: return "iPad Mini 3"
        case .padMini4: return "iPad Mini 4"
        case .padMini5: return "iPad Mini 5th Gen"
        case .padAir3: return "iPad Air 3rd Gen"
        case .padPro9_7: return "iPad Pro (9.7 inch)"
        case .padPro12_9: return "iPad Pro (12.9 inch)"
        case .padPro12_9_2th: return "iPad Pro 2nd Gen"
        case .padPro10_5: return "iPad Pro 10.5-inch"
        case .padPro11: return "iPad Pro 11 inch"
        case .padPro12_9_3th: return "iPad Pro 12.9 inch 3rd Gen"
        case .padPro11_2th: return "iPad Pro 11 inch 2nd Gen"
        case .padPro12_9_4th: return "iPad Pro 12.9 inch 4th Gen"
        case .pad8: return "iPad 8th Gen"
        case .pad9: return "iPad 9th Gen"
        case .pad10: return "iPad 10th Gen"
        case .padAir4: return "iPad Air 4th Gen"
        case .padAir5: return "iPad Air 5th Gen"
        case .padPro11_3th: return "iPad Pro 11 inch 3rd Gen"
        case .padPro11_4th: return "iPad Pro 11 inch 4th Gen"
        case .padPro12_9_6th: return "iPad Pro 12 inch 6th Gen"

        case .podTouch1: return "iPod Touch 1"
        case .podTouch2: return "iPod Touch 2"
        case .podTouch3: return "iPod Touch 3"
        case .podTouch4: return "iPod Touch 4"
        case .podTouch5: return "iPod Touch 5"
        case .podTouch6: return "iPod Touch 6"
        case .podTouch7: return "7th Gen iPod"
        case .simulator: return "Simulator"
        case .unknown: return "Unknown"
        case .phone12mini: return "iPhone 12 Mini"
        case .phone12: return "iPhone 12"
        case .phone12Pro: return "iPhone 12 Pro"
        case .phone12ProMax: return "iPhone 12 Pro Max"
        case .phone13mini: return "iPhone 13 Mini"
        case .phone13: return "iPhone 13"
        case .phone13Pro: return "iPhone 13 Pro"
        case .phone13ProMax: return "iPhone 13 Pro Max"
        case .padPro12_9_5th: return "iPad Pro 5 12.9"
        case .phone14: return "iPhone 14"
        case .phone14Plus: return "iPhone 14 Plus"
        case .phone14Pro: return "iPhone 14 Pro"
        case .phone14ProMax: return "iPhone 14 Pro Max"
        }
    }
}

public extension AlphaWallet.Device {
    /// Available screen sizes
    ///
    /// - parameter unknown:
    /// - parameter inches_3_5:    Representing screens for iPhone 4, 4S
    /// - parameter inches_4_0:    Representing screens for iPhone 5, 5S
    /// - parameter inches_4_7:    Screens for iPhone 6, 6S
    /// - parameter inches_5_5:    Screens for iPhone 6Plus
    /// - parameter inches_7_9:    Screens for iPad Mini
    /// - parameter inches_9_7:    Screens for iPad
    /// - parameter inches_12_9:   Screens for iPad Pro
    enum Screen: CGFloat {
        case unknown     = 0
        case inches_3_5  = 3.5
        case inches_4_0  = 4.0
        case inches_4_7  = 4.7
        case inches_5_4  = 5.4
        case inches_5_5  = 5.5
        case inches_5_8  = 5.8 // iPhone X diagonal
        case inches_6_1  = 6.1
        case inches_6_5  = 6.5
        case inches_6_7  = 6.7
        case inches_7_9  = 7.9
        case inches_8_3  = 8.3
        case inches_9_7  = 9.7
        case inches_10_2 = 10.2
        case inches_10_5 = 10.5
        case inches_10_9 = 10.9
        case inches_11 = 11.0
        case inches_12_9 = 12.9

        /// Return screen family
        public var family: ScreenFamily {
            switch self {
            case .inches_3_5, .inches_4_0: return .old
            case .inches_4_7: return .small
            case .inches_5_4, .inches_5_5, .inches_7_9, .inches_5_8, .inches_6_1, .inches_6_5, .inches_6_7, .inches_8_3: return .medium
            case .inches_9_7, .inches_10_2, .inches_10_5, .inches_10_9, .inches_11, .inches_12_9: return .big
            case .unknown: return .unknown
            }
        }
    }
}

/// Comparing Screen and Screen
public func == (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Screen) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue == rhs.rawValue
}

public func < (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Screen) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue < rhs.rawValue
}

public func > (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Screen) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue > rhs.rawValue
}

public func <= (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Screen) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue <= rhs.rawValue
}

public func >= (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Screen) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue >= rhs.rawValue
}

/// Comparing Screen and Version
public func == (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Version) -> Bool {
    return lhs == rhs.screen
}

public func < (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Version) -> Bool {
    return lhs < rhs.screen
}

public func > (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Version) -> Bool {
    return lhs > rhs.screen
}

public func <= (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Version) -> Bool {
    return lhs <= rhs.screen
}

public func >= (lhs: AlphaWallet.Device.Screen, rhs: AlphaWallet.Device.Version) -> Bool {
    return lhs >= rhs.screen
}

/// These parameters are used to groups device screens into 4 groups:
///
/// - parameter unknown:
/// - parameter old:       In the case Apple stops to produce 3.5 and 4.0 inches devices this will represent it
/// - parameter small:     Include 4.7 inches iPhone 6 size
/// - parameter medium:    Include devices with screen resolution 5.5, 7.9 inches (iPhone 6Plus and iPad mini)
/// - parameter big:       Include devices with bigger screen resolutions (Regular iPad and iPad Pro)
public enum ScreenFamily: String {
    case unknown
    case old
    case small
    case medium
    case big
}

/// Different types of screen scales
///
/// - parameter x1:
/// - parameter x2:
/// - parameter x3:
/// - parameter unknown:
public enum Scale: CGFloat, Comparable, Equatable {
    case x1      = 1.0
    case x2      = 2.0
    case x3      = 3.0
    case unknown = 0
}

public func == (lhs: Scale, rhs: Scale) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue == rhs.rawValue
}

public func < (lhs: Scale, rhs: Scale) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue < rhs.rawValue
}

public func > (lhs: Scale, rhs: Scale) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue > rhs.rawValue
}

public func <= (lhs: Scale, rhs: Scale) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue <= rhs.rawValue
}

public func >= (lhs: Scale, rhs: Scale) -> Bool {
    guard lhs.rawValue > 0 && rhs.rawValue > 0 else { return false }
    return lhs.rawValue >= rhs.rawValue
}

/// Detecting screen properties
extension AlphaWallet.Device {

    /// Detect device screen.
    ///
    /// - seealso: Screen
    static public var screen: AlphaWallet.Device.Screen {
        let size = UIScreen.main.bounds.size
        switch max(size.width, size.height) {
        case 480: return .inches_3_5
        case 568: return .inches_4_0
        case 667: return .inches_4_7
        case 736: return .inches_5_5
        case 812:
            switch version {
            case .phone12mini, .phone13mini: return .inches_5_4
            default: return .inches_5_8
            }
        case 844, 852: return .inches_6_1
        case 896: return ( scale == .x3 ? .inches_6_5 : .inches_6_1 )
        case 926, 932: return .inches_6_7
        case 1024:
            switch version {
            case .padMini, .padMini2, .padMini3, .padMini4: return .inches_7_9
            default: return .inches_9_7
            }
        case 1080:
            switch version {
            case .pad10: return .inches_10_9
            default: return .inches_10_2
            }
        case 1180: return .inches_10_9
        case 1112: return .inches_10_5
        case 1133: return .inches_8_3
        case 1194: return .inches_11
        case 1366: return .inches_12_9
        default: return .unknown
        }
    }

    /// Detect screen resolution scale.
    ///
    /// - Seealso: Scale
    static public var scale: Scale {
        switch UIScreen.main.scale {
        case 1.0: return .x1
        case 2.0: return .x2
        case 3.0: return .x3
        default: return .unknown
        }
    }

    /// Return `true` for retina displays
    static public var isRetina: Bool {
        return scale > Scale.x1
    }
}

/// Work with sizes
extension AlphaWallet.Device {

    /// Returns size for a specific device (iPad or iPhone/iPod)
    static public func size<T: Any>(phone: T, pad: T) -> T {
        return AlphaWallet.Device.isPad ? pad : phone
    }

    /// Return size depending on specific screen family.
    /// If Screen size is unknown (in this case ScreenFamily will be unknown too) it will return small value
    ///
    /// `old` screen family is optional and if not defined will return `small` value
    ///
    /// - seealso: Screen, ScreenFamily
    static public func size<T: Any>(old: T? = nil, small: T, medium: T, big: T) -> T {
        switch AlphaWallet.Device.screen.family {
        case .old:
            return old ?? small
        case .small:
            return small
        case .medium:
            return medium
        case .big:
            return big
        case .unknown:
            return small
        }
    }

    /// Return value for specific screen size. Incoming parameter should be a screen size. If it is not defined
    /// nearest value will be used. Code example:
    ///
    /// ```
    /// let sizes: [Screen:AnyObject] = [
    ///     .inches_3_5: 12,
    ///     .inches_4_0: 13,
    ///     .inches_4_7: 14,
    ///     .inches_9_7: 15
    ///    ]
    /// let exactSize = Device.size(sizes: sizes) as! Int
    /// let _ = UIFont(name: "Arial", size: CGFloat(exactSize))
    /// ```
    ///
    /// After that your font will be:
    /// * 12 for 3.5" inches (older devices)
    /// * 13 for iPhone 5, 5S
    /// * 14 for iPhone 6, 6Plus and iPad mini
    /// * and 15 for other iPads
    ///
    /// - seealso: Screen
    static public func size<T: Any>(sizes: [AlphaWallet.Device.Screen: T]) -> T? {
        let screen = AlphaWallet.Device.screen
        var nearestValue: T?
        var distance = CGFloat.greatestFiniteMagnitude

        for (key, value) in sizes {
            // Prevent from iterating whole array
            if key == screen {
                return value
            }

            let actualDistance = abs(key.rawValue - screen.rawValue)
            if actualDistance < distance {
                nearestValue = value
                distance = actualDistance
            }
        }

        return nearestValue
    }
}
