//
//  GameProgressStore.swift
//  apexRunner
//
//  Persistent player progress: coins, unlocked skins, purchased skills.
//

import Foundation
import SwiftUI

// MARK: - PowerUpType

enum PowerUpType: String, CaseIterable {
    case shield = "shield"  // Survive one collision
    case boost  = "boost"   // Speed +50 % for a few seconds
    case toxin  = "toxin"   // Destroy obstacles in current lane ahead

    var duration: Float {
        switch self {
        case .shield: return 8.0
        case .boost:  return 6.0
        case .toxin:  return 5.0
        }
    }

    var displayName: String {
        switch self {
        case .shield: return "SHIELD"
        case .boost:  return "BOOST"
        case .toxin:  return "TOXIN"
        }
    }

    var icon: String {
        switch self {
        case .shield: return "shield.fill"
        case .boost:  return "bolt.fill"
        case .toxin:  return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .shield: return Color(red: 0.0, green: 0.75, blue: 1.0)
        case .boost:  return Color(red: 1.0, green: 0.65, blue: 0.0)
        case .toxin:  return Color(red: 0.2, green: 1.0, blue: 0.3)
        }
    }
}

// MARK: - CharacterSkin

struct CharacterSkin: Identifiable {
    let id: String
    let displayName: String
    let price: Int
    let icon: String
    // SwiftUI preview color (used in ShopView cards)
    let previewColor: Color
    // Readable label colors for GameController
    let bodyR: CGFloat; let bodyG: CGFloat; let bodyB: CGFloat
    let emissionR: CGFloat; let emissionG: CGFloat; let emissionB: CGFloat
    let accentR: CGFloat; let accentG: CGFloat; let accentB: CGFloat
    let altR: CGFloat; let altG: CGFloat; let altB: CGFloat

    static let all: [CharacterSkin] = [
        CharacterSkin(id: "default", displayName: "GHOST", price: 0, icon: "person.fill",
                      previewColor: .cyan,
                      bodyR: 0.88, bodyG: 0.88, bodyB: 0.95,
                      emissionR: 0.25, emissionG: 0.22, emissionB: 0.45,
                      accentR: 0.0, accentG: 0.95, accentB: 1.0,
                      altR: 1.0, altG: 0.1, altB: 0.6),

        CharacterSkin(id: "inferno", displayName: "INFERNO", price: 50, icon: "flame.fill",
                      previewColor: Color(red: 1.0, green: 0.4, blue: 0.0),
                      bodyR: 0.90, bodyG: 0.30, bodyB: 0.05,
                      emissionR: 0.50, emissionG: 0.10, emissionB: 0.00,
                      accentR: 1.0, accentG: 0.65, accentB: 0.0,
                      altR: 1.0, altG: 0.20, altB: 0.0),

        CharacterSkin(id: "phantom", displayName: "PHANTOM", price: 75, icon: "moon.stars.fill",
                      previewColor: Color(red: 0.7, green: 0.0, blue: 1.0),
                      bodyR: 0.25, bodyG: 0.08, bodyB: 0.42,
                      emissionR: 0.40, emissionG: 0.00, emissionB: 0.65,
                      accentR: 0.80, accentG: 0.00, accentB: 1.0,
                      altR: 0.50, altG: 0.00, altB: 1.0),

        CharacterSkin(id: "titan", displayName: "TITAN", price: 100, icon: "bolt.shield.fill",
                      previewColor: Color(red: 0.1, green: 0.5, blue: 1.0),
                      bodyR: 0.12, bodyG: 0.32, bodyB: 0.85,
                      emissionR: 0.00, emissionG: 0.20, emissionB: 0.55,
                      accentR: 0.20, accentG: 0.85, accentB: 1.0,
                      altR: 0.00, altG: 0.50, altB: 1.0),
    ]

    static func find(_ id: String) -> CharacterSkin {
        all.first { $0.id == id } ?? all[0]
    }
}

// MARK: - PassiveSkill

struct PassiveSkill: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let price: Int
    let icon: String
    let color: Color

    static let all: [PassiveSkill] = [
        PassiveSkill(id: "magnet", displayName: "MAGNET",
                     description: "Coin attraction radius ×3",
                     price: 80, icon: "arrow.down.circle.fill",
                     color: Color(red: 1.0, green: 0.85, blue: 0.0)),
        PassiveSkill(id: "headstart", displayName: "HEADSTART",
                     description: "Begin each run at boosted speed",
                     price: 60, icon: "hare.fill",
                     color: Color(red: 1.0, green: 0.4, blue: 0.0)),
        PassiveSkill(id: "saver", displayName: "LIFE SAVER",
                     description: "Survive the first collision",
                     price: 120, icon: "heart.fill",
                     color: Color(red: 1.0, green: 0.15, blue: 0.4)),
    ]

    static func find(_ id: String) -> PassiveSkill? { all.first { $0.id == id } }
}

// MARK: - GameProgressStore

@Observable
final class GameProgressStore {
    static let shared = GameProgressStore()

    private(set) var totalCoins: Int = 0
    private(set) var selectedSkinId: String = "default"
    private(set) var purchasedSkinIds: Set<String> = ["default"]
    private(set) var purchasedSkillIds: Set<String> = []
    private(set) var selectedTheme: String = "neon"   // "neon" | "minimal"

    var selectedSkin: CharacterSkin { CharacterSkin.find(selectedSkinId) }

    private init() {
        totalCoins        = UserDefaults.standard.integer(forKey: "gp.coins")
        selectedSkinId    = UserDefaults.standard.string(forKey: "gp.skin")   ?? "default"
        selectedTheme     = UserDefaults.standard.string(forKey: "gp.theme")  ?? "neon"
        purchasedSkinIds  = Set(UserDefaults.standard.stringArray(forKey: "gp.skins")  ?? ["default"])
        purchasedSkillIds = Set(UserDefaults.standard.stringArray(forKey: "gp.skills") ?? [])
        purchasedSkinIds.insert("default")
    }

    // MARK: Theme
    func setTheme(_ id: String) {
        selectedTheme = id
        UserDefaults.standard.set(id, forKey: "gp.theme")
    }

    // MARK: Coins
    func addCoins(_ n: Int) {
        totalCoins += n
        UserDefaults.standard.set(totalCoins, forKey: "gp.coins")
    }

    // MARK: Skins
    func selectSkin(_ id: String) {
        guard purchasedSkinIds.contains(id) else { return }
        selectedSkinId = id
        UserDefaults.standard.set(id, forKey: "gp.skin")
    }

    func purchaseSkin(_ id: String) -> Bool {
        let skin = CharacterSkin.find(id)
        guard totalCoins >= skin.price, !purchasedSkinIds.contains(id) else { return false }
        totalCoins -= skin.price
        purchasedSkinIds.insert(id)
        UserDefaults.standard.set(totalCoins, forKey: "gp.coins")
        UserDefaults.standard.set(Array(purchasedSkinIds), forKey: "gp.skins")
        return true
    }

    // MARK: Skills
    func purchaseSkill(_ id: String) -> Bool {
        guard let skill = PassiveSkill.find(id) else { return false }
        guard totalCoins >= skill.price, !purchasedSkillIds.contains(id) else { return false }
        totalCoins -= skill.price
        purchasedSkillIds.insert(id)
        UserDefaults.standard.set(totalCoins, forKey: "gp.coins")
        UserDefaults.standard.set(Array(purchasedSkillIds), forKey: "gp.skills")
        return true
    }

    var hasMagnet:    Bool { purchasedSkillIds.contains("magnet") }
    var hasHeadstart: Bool { purchasedSkillIds.contains("headstart") }
    var hasSaver:     Bool { purchasedSkillIds.contains("saver") }
}
