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

enum RunGoalKind: String, Equatable {
    case distance
    case coins
    case combo
    case level
}

struct RunGoal: Equatable {
    let kind: RunGoalKind
    let title: String
    let target: Int
    let rewardCoins: Int
    var progress: Int = 0
    var isCompleted: Bool = false

    var progressText: String { "\(min(progress, target))/\(target)" }
    var progressFraction: Float { min(Float(progress) / Float(target), 1) }

    static func makeForRun() -> RunGoal {
        let goals: [RunGoal] = [
            RunGoal(kind: .distance, title: "RUN 500M", target: 500, rewardCoins: 8),
            RunGoal(kind: .coins, title: "COLLECT 12", target: 12, rewardCoins: 10),
            RunGoal(kind: .combo, title: "COMBO 8", target: 8, rewardCoins: 12),
            RunGoal(kind: .level, title: "REACH LVL 3", target: 3, rewardCoins: 15)
        ]
        return goals.randomElement() ?? goals[0]
    }
}

@Observable
final class GameState {
    var phase: GamePhase = .menu
    var score: Int = 0
    var distanceMeters: Float = 0
    var currentSpeed: Float = 12.0
    var highScore: Int = UserDefaults.standard.integer(forKey: "apexRunner.highScore")
    private var distanceScore: Int = 0
    private var bonusScore: Int = 0
    var streakBonusCoins: Int = 0

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
    var runGoal: RunGoal = .makeForRun()
    var showGoalComplete: Bool = false

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
        distanceScore = 0
        bonusScore = 0
        streakBonusCoins = 0
        distanceMeters = 0
        currentSpeed = 12.0
        comboCount = 0
        scoreMultiplier = 1
        coinCount = 0
        currentLevel = .level(1)
        levelProgress = 0
        showLevelUp = false
        runGoal = .makeForRun()
        showGoalComplete = false
        showComboUp = false
        showNearMiss = false
        showSaverWarning = false
        activePowerUps.removeAll()
        phase = .playing
    }

    func triggerGameOver() {
        // Persist coins earned this run
        GameProgressStore.shared.addCoins(coinCount)
        streakBonusCoins = GameProgressStore.shared.finishRunGoal(completed: runGoal.isCompleted)
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

    func updateRunProgress(distance: Float, distanceScore: Int, speed: Float) {
        distanceMeters = distance
        self.distanceScore = distanceScore
        currentSpeed = speed
        updateLevel(distance: distance)
        updateGoalProgress()
        recalculateScore()
    }

    private func updateGoalProgress() {
        guard !runGoal.isCompleted else { return }

        switch runGoal.kind {
        case .distance:
            runGoal.progress = Int(distanceMeters)
        case .coins:
            runGoal.progress = coinCount
        case .combo:
            runGoal.progress = comboCount
        case .level:
            runGoal.progress = currentLevel.number
        }

        guard runGoal.progress >= runGoal.target else { return }
        runGoal.progress = runGoal.target
        runGoal.isCompleted = true
        coinCount += runGoal.rewardCoins
        showGoalComplete = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.showGoalComplete = false
        }
        SoundManager.shared.play(.milestone)
    }

    private func recalculateScore() {
        score = distanceScore + bonusScore
    }

    // MARK: - Combo

    func incrementCombo() {
        comboCount += 1
        updateGoalProgress()
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
        bonusScore += 10 * scoreMultiplier
        updateGoalProgress()
        recalculateScore()
        SoundManager.shared.play(.coinCollect)
    }

    // MARK: - Near Miss

    func triggerNearMiss() {
        bonusScore += 3 * scoreMultiplier
        recalculateScore()
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
