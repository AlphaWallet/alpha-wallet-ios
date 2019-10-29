// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

// swiftlint:disable type_body_length
enum OpenSeaNonFungibleTokenDisplayHelper: String {
    //Make sure contracts are all lowercased. The cases don't always match the token symbol since there are name-clashes
    case axie = "0xf5b0a3efb8e8e4c201e2a935f110eaaf3ffecb8d"
    case bc = "0xd73be539d6b2076bab83ca6ba62dfe189abc6bbe"
    case cbt = "0xf7a6e15dfd5cdd9ef12711bd757a9b6021abf643"
    case ck = "0x06012c8cf97bead5deae237070f9587f8e7a266d"
    case emona = "0x5d00d312e171be5342067c09bae883f9bcb2003b"
    case emond = "0xbfde6246df72d3ca86419628cac46a9d2b60393c"
    case etht = "0x995020804986274763df9deb0296b754f2659ca1"
    case ethtown_hero = "0x4fece400c0d3db0937162ab44bab34445626ecfe"
    case fighter = "0x87d598064c736dd0c712d329afcfaa0ccc1921a1"
    case gods = "0x6ebeaf8e8e946f0716e6533a6f2cefc83f60e8ab"
    case hd = "0x7fdcd2a1e52f10c28cb7732f46393e297ecadda1"
    case hero = "0xabc7e6c01237e8eef355bba2bf925a730b714d5f"
    case mchh = "0x273f7f8e6489682df756151f5525576e322d51a3"
    case mlbcb = "0x8c9b261faef3b3c2e64ab5e58e04615f8c788099"
    case myth = "0xc70be5b7c19529ef642d16c10dfe91c58b5c3bf0"
    case pe = "0x663e4229142a27f00bafb5d087e1e730648314c3"
    case pti = "0x9d9c250311b65803c895cc77f878b8092019dedc"
    case strk = "0xdcaad9fd9a74144d226dbf94ce6162ca9f09ed7e"
    case wr = "0x5caebd3b32e210e85ce3e9d51638b9c445481567"
    case others = ""

    private enum TraitsToHide {
        case toHide([String])
        case hideAll
    }

    //Using "kat" instead of "cryptokitties" to avoid being mistakenly detected by app review as supporting CryptoKitties
    private static let katCooldowns = [
        "Fast",
        "Swift",
        "Swift",
        "Snappy",
        "Snappy",
        "Brisk",
        "Brisk",
        "Ploddy",
        "Ploddy",
        "Slow",
        "Slow",
        "Sluggish",
        "Sluggish",
        "Catatonic",
        "Catatonic"
    ]

    private static let ethertuplisRarity = [
        "Very Common",
        "Very Common",
        "Common",
        "Uncommon",
        "Rare",
        "Very Rare",
        "Epic",
        "Legendary",
        "MOOOON"
    ]

    private static let cryptoFightersRank = [
        "General",
        "1st Colonel",
        "2nd Colonel",
        "1st Major",
        "2nd Major"
    ]

    private static let cryptoFightersCooldown = [
        "1 minute",
        "30 minutes",
        "2 hours",
        "6 hours",
        "12 hours",
        "1 day",
        "3 days"
    ]

    init(contract: AlphaWallet.Address) {
        self = OpenSeaNonFungibleTokenDisplayHelper(rawValue: contract.eip55String.lowercased()) ?? .others
    }

    var imageHasBackgroundColor: Bool {
        switch self {
        case .axie:
            return true
        case .bc:
            return false
        case .cbt:
            return false
        case .ck:
            return false
        case .emona, .emond:
            return true
        case .etht:
            return false
        case .ethtown_hero:
            return false
        case .fighter:
            return false
        case .gods:
            return true
        case .hd:
            return false
        case .hero:
            return false
        case .mchh:
            return false
        case .mlbcb:
            return false
        case .myth:
            return true
        case .pe:
            return false
        case .pti:
            return false
        case .strk:
            return true
        case .wr:
            return true
        case .others:
            //Rather get it wrong and have a collectible without a background, then have a solid color background behind, say a painting collectible
            return true
        }
    }

    private var traitsToProperNames: [String: String] {
        switch self {
        case .axie:
            return [
                "hp": "HP",
            ]
        case .bc:
            return [:]
        case .cbt:
            return [:]
        case .ck:
            return [
                "body": "Fur",
                "coloreyes": "Eye Color",
                "eyes": "Eye Shape",
                "colorprimary": "Base Color",
                "colorsecondary": "Highlight Color",
                "colortertiary": "Accent Color",
            ]
        case .emona, .emond:
            return [
                "bp": "BP",
                "hp": "HP",
                "pa": "PA",
                "pd": "PD",
                "sa": "SA",
                "sd": "SD",
                "sp": "SP",
                "exp": "EXP",
            ]
        case .etht:
            return [:]
        case .ethtown_hero:
            return [:]
        case .fighter:
            return [
                "prize_cooldown_index": "Recruitment Speed"
            ]
        case .gods:
            return [:]
        case .hd:
            return [:]
        case .hero:
            return [:]
        case .mchh:
            return [
                "phy": "PHY",
                "int": "INT",
                "hp": "HP",
                "agi": "AGI",
            ]
        case .mlbcb:
            return [
                "uniform_number": "Jersey Number",
                "team_name": "Team"
            ]
        case .myth:
            return [:]
        case .pe:
            return [:]
        case .pti:
            return [:]
        case .strk:
            return [:]
        case .wr:
            return [:]
        case .others:
            return [:]
        }
    }

    private var attributesToHide: TraitsToHide {
        switch self {
        case .axie:
            return .toHide([
                "hp",
                "speed",
                "skill",
                "morale",
                "exp",
                "level",
            ])
        case .bc:
            return .toHide([])
        case .cbt:
            return .toHide([])
        case .ck:
            return .toHide([
                "generation",
                "cooldown_index"
            ])
        case .emona, .emond:
            return .toHide([
                "bp",
                "hp",
                "pa",
                "pd",
                "sa",
                "sd",
                "sp",
                "exp",
                "level",
            ])
        case .etht:
            return .toHide([
            "health",
            "intelligence",
            "agility",
            "strength",
            "armor",
            "damage",
            ])
        case .ethtown_hero:
            return .toHide([
                "luck",
                "agility",
                "intellect",
                "strength",
            ])
        case .fighter:
            return .toHide([
                "strength",
                "vitality",
                "dexterity",
                "luck",
            ])
        case .gods:
            return .toHide([
                "health",
                "attack",
                "mana",
                "purity",
            ])
        case .hd:
            return .toHide([])
        case .hero:
            return .toHide([
                "BP",
                "LUK",
                "AGL",
                "DEF",
                "ATK",
                "HP",
            ])
        case .mchh:
            return .toHide([
                "hero_name",
                "phy",
                "int",
                "hp",
                "agi",
            ])
        case .mlbcb:
            return .toHide([])
        case .myth:
            return .toHide([])
        case .pe:
            return .toHide([])
        case .pti:
            return .toHide([
                "name",
                "rarity",
            ])
        case .strk:
            return .toHide([
                "player",
                "set",
            ])
        case .wr:
            return .toHide([
                "Acceleration",
                "Armor",
                "BZN Tank",
                "Engine Size",
                "Speed",
            ])
        case .others:
            return .toHide([])
        }
    }

    private var rankingsToHide: TraitsToHide {
        switch self {
        case .axie:
            return .hideAll
        case .bc:
            return .hideAll
        case .cbt:
            return .hideAll
        case .ck:
            return .hideAll
        case .emona, .emond:
            return .hideAll
        case .etht:
            return .toHide([
                "health",
                "intelligence",
                "agility",
                "strength",
                "armor",
                "damage",
            ])
        case .ethtown_hero:
            return .toHide([
                "luck",
                "agility",
                "intellect",
                "strength",
            ])
        case .fighter:
            return .toHide([
                "strength",
                "vitality",
                "dexterity",
                "luck",
            ])
        case .gods:
            return .toHide([
                "health",
                "attack",
                "mana",
                "purity",
            ])
        case .hd:
            return .toHide([])
        case .hero:
            return .toHide([
                "BP",
                "LUK",
                "AGL",
                "DEF",
                "ATK",
                "HP",
            ])
        case .mchh:
            return .hideAll
        case .mlbcb:
            return .toHide([
                "ability_string",
                "position_name",
                "stance",
                "bat_type",
            ])
        case .myth:
            return .toHide([])
        case .pe:
            return .toHide([])
        case .pti:
            return .toHide([
                "name",
                "rarity",
            ])
        case .strk:
            return .toHide([
                "player",
                "set",
            ])
        case .wr:
            return .toHide([
                "Acceleration",
                "Armor",
                "BZN Tank",
                "Engine Size",
                "Speed",
            ])
        case .others:
            return .hideAll
        }
    }

    private var statsToHide: TraitsToHide {
        switch self {
        case .axie:
            return .toHide([
                "parts",
                "title",
            ])
        case .bc:
            return .hideAll
        case .cbt:
            return .hideAll
        case .ck:
            return .hideAll
        case .emona, .emond:
            return .toHide([
                "class_name",
            ])
        case .etht:
            return .toHide([])
        case .ethtown_hero:
            return .toHide([])
        case .fighter:
            return .toHide([])
        case .gods:
            return .toHide([])
        case .hd:
            return .toHide([])
        case .hero:
            return .toHide([])
        case .mchh:
            return .toHide([
                "hero_name",
                "rarity",
            ])
        case .mlbcb:
            return .toHide([
                "ability_string",
                "position_name",
                "stance",
                "bat_type",
            ])
        case .myth:
            return .toHide([])
        case .pe:
            return .toHide([])
        case .pti:
            return .toHide([
                "name",
                "rarity",
            ])
        case .strk:
            return .toHide([
                "player",
                "set",
            ])
        case .wr:
            return .toHide([])
        case .others:
            return .hideAll
        }
    }

    var attributesLabelName: String {
        switch self {
        case .axie:
            return "Body Parts"
        case .cbt:
            return "Modules"
        case .ck:
            return "CAttributes"
        case .bc, .emona, .emond, .etht, .fighter, .gods, .hd, .hero, .mlbcb, .pe, .pti, .strk, .wr, .others:
            return "Attributes"
        case .ethtown_hero, .mchh, .myth:
            return "Properties"
        }
    }

    var rankingsLabelName: String {
        return "Rankings"
    }

    var statsLabelName: String {
        switch self {
        case .etht:
            return "Battle Stats"
        case .axie, .bc, .cbt, .ck, .emona, .emond, .ethtown_hero, .fighter, .gods, .hd, .hero, .mchh, .mlbcb, .myth, .pe, .pti, .strk, .wr, .others:
            return "Stats"
        }
    }

    var hasLotsOfEmptySpaceAroundBigImage: Bool {
        switch self {
        case .ck:
            return true
        case .axie, .bc, .cbt, .emona, .emond, .etht, .ethtown_hero, .fighter, .gods, .hd, .hero, .mchh, .mlbcb, .myth, .pe, .pti, .strk, .wr, .others:
            return false
        }
    }

    var subtitle1TraitName: String? {
        switch self {
        case .axie:
            return "exp"
        case .bc:
            return "generation"
        case .cbt:
            return "generation"
        case .ck:
            return "generation"
        case .mchh:
            return "hero_name"
        case .others:
            return nil
        case .emona, .emond:
            return "class_name"
        case .etht:
            return "generation"
        case .ethtown_hero:
            return "level"
        case .fighter:
            return "generation"
        case .gods:
            return "type"
        case .hd:
            return "generation"
        case .hero:
            return "type"
        case .mlbcb:
            return "team_name"
        case .myth:
            return "class"
        case .pe:
            return "gen"
        case .pti:
            return "city"
        case .strk:
            return "country"
        case .wr:
            return "Equipment Slots"
        }
    }

    var subtitle2TraitName: String? {
        switch self {
        case .axie:
            return "level"
        case .bc:
            return nil
        case .cbt:
            return "power"
        case .ck:
            return "cooldown_index"
        case .mchh:
            return "rarity"
        case .others:
            return nil
        case .emona, .emond:
            return nil
        case .etht:
            return "rarity"
        case .ethtown_hero:
            return "investor_power_percentage"
        case .fighter:
            return "battles_won"
        case .gods:
            return "rarity"
        case .hd:
            return "cooldown"
        case .hero:
            return "current_level"
        case .mlbcb:
            return "uniform_number"
        case .myth:
            return nil
        case .pe:
            return nil
        case .pti:
            return nil
        case .strk:
            return "serial_number"
        case .wr:
            return "Main Gun Slots"
        }
    }

    var subtitle3TraitName: String? {
        switch self {
        case .axie:
            return nil
        case .bc:
            return nil
        case .cbt:
            return nil
        case .ck:
            return nil
        case .mchh:
            return nil
        case .others:
            return nil
        case .emona, .emond:
            return nil
        case .etht:
            return "BP"
        case .ethtown_hero:
            return nil
        case .fighter:
            return "battles_fought"
        case .gods:
            return nil
        case .hd:
            return "fight_cooldown"
        case .hero:
            return "max_level"
        case .mlbcb:
            return nil
        case .myth:
            return nil
        case .pe:
            return nil
        case .pti:
            return nil
        case .strk:
            return nil
        case .wr:
            return "Additional Gun Slots"
        }
    }

    func mapTraitsToDisplayName(name: String) -> String {
        return traitsToProperNames[name] ?? name.replacingOccurrences(of: "_", with: " ").titleCasedWords()
    }

    func mapTraitsToDisplayValue(name: String, value: String) -> String {
        let defaultConvertedValue = value.replacingOccurrences(of: "_", with: " ").titleCasedWords()
        switch self {
        case .axie:
            switch name {
            case "level":
                return "Level: \(value)"
            case "exp":
                return "Exp: \(value)"
            default:
                return defaultConvertedValue
            }
        case .bc:
            switch name {
            case "generation":
                return "Generation \(value)"
            default:
                return defaultConvertedValue
            }
        case .cbt:
            switch name {
            case "generation":
                return "Gen \(value)"
            case "power":
                return "Power \(value)"
            default:
                return defaultConvertedValue
            }
        case .ck:
            switch name {
            case "cooldown_index":
                if let index = Int(value) {
                    if OpenSeaNonFungibleTokenDisplayHelper.katCooldowns.indices.contains(index) {
                        return "\(OpenSeaNonFungibleTokenDisplayHelper.katCooldowns[index]) Cooldown"
                    } else {
                        return "Unknown Cooldown"
                    }
                } else {
                    return defaultConvertedValue
                }
            case "generation":
                return "Gen \(value)"
            default:
                return defaultConvertedValue
            }
        case .emona, .emond:
            switch name {
            case "class_name":
                return value
            default:
                return defaultConvertedValue
            }
        case .etht:
            switch name {
            case "generation":
                return "Gen: \(value)"
            case "rarity":
                if let index = Int(value) {
                    if OpenSeaNonFungibleTokenDisplayHelper.ethertuplisRarity.indices.contains(index) {
                        return OpenSeaNonFungibleTokenDisplayHelper.ethertuplisRarity[index]
                    } else {
                        return "Unknown"
                    }
                } else {
                    return defaultConvertedValue
                }
            case "BP":
                return "BP \(value)"
            default:
                return defaultConvertedValue
            }
        case .ethtown_hero:
            switch name {
            case "level":
                return "Level: \(value)"
            case "investor_power_percentage":
                return "\(value)% investor power"
            default:
                return defaultConvertedValue
            }
        case .fighter:
            switch name {
            case "prize_cooldown_index":
                if let index = Int(value) {
                    if OpenSeaNonFungibleTokenDisplayHelper.cryptoFightersCooldown.indices.contains(index) {
                        return OpenSeaNonFungibleTokenDisplayHelper.cryptoFightersCooldown[index]
                    } else {
                        return "Unknown"
                    }
                } else {
                    return defaultConvertedValue
                }
            case "battles_won":
                return "Wins: \(value)"
            case "battles_fought":
                return value
            case "generation":
                if let index = Int(value) {
                    if OpenSeaNonFungibleTokenDisplayHelper.cryptoFightersRank.indices.contains(index) {
                        return OpenSeaNonFungibleTokenDisplayHelper.cryptoFightersRank[index]
                    } else {
                        return "Unknown"
                    }
                } else {
                    return defaultConvertedValue
                }
            default:
                return defaultConvertedValue
            }
        case .gods:
            return defaultConvertedValue
        case .hd:
            switch name {
            case "cooldown":
                return "\(value)"
            case "generation":
                return "Gen \(value)"
            case "fight_cooldown":
                return "\(value) Cooldown"
            default:
                return defaultConvertedValue
            }
        case .mlbcb:
            switch name {
            case "uniform_number":
                return "#\(value)"
            default:
                return defaultConvertedValue
            }
        case .pe:
            switch name {
            case "gen":
                return "Gen \(value)"
            default:
                return defaultConvertedValue
            }
        case .strk:
            switch name {
            case "serial_number":
                return "#\(value)"
            default:
                return defaultConvertedValue
            }
        case .wr:
            switch name {
            case "Equipment Slots":
                return "Equipment Slots: \(value)"
            case "Main Gun Slots":
                return "Gun Slots: \(value)"
            case "Additional Gun Slots":
                return value
            default:
                return defaultConvertedValue
            }
        case .hero:
            switch name {
            case "current_level":
                return "Level: \(value)"
            default:
                return defaultConvertedValue
            }
        case .mchh, .myth, .pti, .others:
            return defaultConvertedValue
        }
    }

    func shouldDisplayAttribute(name: String) -> Bool {
        if subtitle1TraitName == name || subtitle2TraitName == name || subtitle3TraitName == name {
            return false
        }
        switch attributesToHide {
        case .toHide(let list):
            return !list.contains(name)
        case .hideAll:
            return false
        }
    }

    func shouldDisplayRanking(name: String) -> Bool {
        if subtitle1TraitName == name || subtitle2TraitName == name || subtitle3TraitName == name {
            return false
        }
        switch rankingsToHide {
        case .toHide(let list):
            if shouldDisplayAttribute(name: name) {
                return false
            } else {
                return !list.contains(name)
            }
        case .hideAll:
            return false
        }
    }

    func shouldDisplayStat(name: String) -> Bool {
        if subtitle1TraitName == name || subtitle2TraitName == name || subtitle3TraitName == name {
            return false
        }
        switch statsToHide {
        case .toHide(let list):
            if shouldDisplayAttribute(name: name) {
                return false
            } else {
                return !list.contains(name)
            }
        case .hideAll:
            return false
        }
    }

    func title(fromTokenName tokenName: String, tokenId: String) -> String {
        switch self {
        case .ck:
            return "Kitty #\(tokenId)"
        case .axie, .bc, .cbt, .emona, .emond, .etht, .ethtown_hero, .fighter, .gods, .hd, .hero, .mchh, .mlbcb, .myth, .pe, .pti, .strk, .wr, .others:
            return "\(tokenName) #\(tokenId)"
        }
    }
}
// swiftlint:enable type_body_length
