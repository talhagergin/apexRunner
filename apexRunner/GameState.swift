//
//  GameState.swift
//  apexRunner
//

import Foundation
import Observation

enum GamePhase: Equatable {
    case menu
    case playing
    case gameOver
}

struct GameLevel: Equatable {
    let number: Int
    let title: String
    let startDistance: Float
    let endDistance: Float
    let speedGrowthRate: Float
    let maxSpeed: Float
    let maxObstacleCount: Int
    let obstacleSpawnChance: Int
    let powerUpSpawnChance: Int

    var length: Float { endDistance - startDistance }

    static func level(for distance: Float) -> GameLevel {
        let number = max(1, Int(distance / 250.0) + 1)
        return level(number)
    }

    static func level(_ number: Int) -> GameLevel {
        let levelNumber = max(1, number)
        let start = Float(levelNumber - 1) * 250.0
        let end = start + 250.0
        let growth = min(0.4 + Float(levelNumber - 1) * 0.08, 0.95)
        let maxSpeed = min(40.0 + Float(levelNumber - 1) * 2.5, 58.0)
        let maxObstacleCount = min(1 + (levelNumber / 3), 3)
        let obstacleChance = max(1, 2 - min((levelNumber - 1) / 2, 1))
        let powerUpChance = max(2, 5 - min(levelNumber / 3, 3))

        return GameLevel(
            number: levelNumber,
            title: title(for: levelNumber),
            startDistance: start,
            endDistance: end,
            speedGrowthRate: growth,
            maxSpeed: maxSpeed,
            maxObstacleCount: maxObstacleCount,
            obstacleSpawnChance: obstacleChance,
            powerUpSpawnChance: powerUpChance
        )
    }

    private static func title(for level: Int) -> String {
        switch level {
        case 1: return "NEON ENTRY"
        case 2: return "GLASSWAY"
        case 3: return "HYPER LANE"
        case 4: return "SKYLINE RUSH"
        case 5: return "APEX ZONE"
        default: return "APEX ZONE \(level - 4)"
        }
    }
}

@Observable
final class GameState {
    var phase: GamePhase = .menu
    var score: Int = 0
    var distanceMeters: Float = 0
    var currentSpeed: Float = 12.0
    var highScore: Int = UserDefaults.standard.integer(forKey: "apexRunner.highScore")

    // Combo & multiplier
    var comboCount: Int = 0
    var scoreMultiplier: Int = 1
    var showComboUp: Bool = false

    // Coins (this run)
    var coinCount: Int = 0

    // Level progression
    var currentLevel: GameLevel = .level(1)
    var levelProgress: Float = 0
    var showLevelUp: Bool = false

    // Near-miss feedback
    var showNearMiss: Bool = false

    // Power-ups: type rawValue → remaining seconds
    var activePowerUps: [String: Float] = [:]

    // Saver-skill warning (first hit, don't die)
    var showSaverWarning: Bool = false

    // MARK: Computed
    var hasShield: Bool { activePowerUps[PowerUpType.shield.rawValue] != nil }
    var hasBoost:  Bool { activePowerUps[PowerUpType.boost.rawValue]  != nil }
    var hasToxin:  Bool { activePowerUps[PowerUpType.toxin.rawValue]  != nil }

    // MARK: - Game Flow

    func startGame() {
        score = 0
        distanceMeters = 0
        currentSpeed = 12.0
        comboCount = 0
        scoreMultiplier = 1
        coinCount = 0
        currentLevel = .level(1)
        levelProgress = 0
        showLevelUp = false
        showComboUp = false
        showNearMiss = false
        showSaverWarning = false
        activePowerUps.removeAll()
        phase = .playing
    }

    func triggerGameOver() {
        // Persist coins earned this run
        GameProgressStore.shared.addCoins(coinCount)
        if score > highScore {
            highScore = score
            UserDefaults.standard.set(highScore, forKey: "apexRunner.highScore")
        }
        phase = .gameOver
    }

    // MARK: - Levels

    func updateLevel(distance: Float) {
        let nextLevel = GameLevel.level(for: distance)
        levelProgress = min(max((distance - nextLevel.startDistance) / nextLevel.length, 0), 1)

        guard nextLevel.number != currentLevel.number else { return }
        currentLevel = nextLevel
        showLevelUp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            self?.showLevelUp = false
        }
        SoundManager.shared.play(.milestone)
    }

    // MARK: - Combo

    func incrementCombo() {
        comboCount += 1
        let newMult = multiplierFor(comboCount)
        if newMult > scoreMultiplier {
            scoreMultiplier = newMult
            showComboUp = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.showComboUp = false
            }
            SoundManager.shared.play(.comboUp)
        }
    }

    func resetCombo() {
        comboCount = 0
        scoreMultiplier = 1
    }

    private func multiplierFor(_ combo: Int) -> Int {
        switch combo {
        case 0..<3:  return 1
        case 3..<7:  return 2
        case 7..<12: return 3
        default:     return 5
        }
    }

    // MARK: - Coins

    func collectCoin() {
        coinCount += 1
        score += 10 * scoreMultiplier
        SoundManager.shared.play(.coinCollect)
    }

    // MARK: - Near Miss

    func triggerNearMiss() {
        score += 3 * scoreMultiplier
        showNearMiss = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.showNearMiss = false
        }
    }

    // MARK: - Power-ups

    func activatePowerUp(_ type: PowerUpType) {
        activePowerUps[type.rawValue] = type.duration
        SoundManager.shared.play(.milestone)
    }

    /// Called every frame from GameController to decrement timers.
    func tickPowerUps(delta: Float) {
        for key in activePowerUps.keys {
            activePowerUps[key]! -= delta
            if activePowerUps[key]! <= 0 {
                activePowerUps.removeValue(forKey: key)
            }
        }
    }

    func remainingTime(for type: PowerUpType) -> Float {
        activePowerUps[type.rawValue] ?? 0
    }
}
