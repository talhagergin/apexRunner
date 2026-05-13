//
//  HUDView.swift
//  apexRunner
//
//  Score, speed, combo, coins, near-miss, power-up timer bars, saver warning.
//

import SwiftUI

struct HUDView: View {
    var gameState: GameState

    var body: some View {
        VStack {
            // ── Top bar ──────────────────────────────────────────
            HStack(alignment: .top, spacing: 12) {
                scorePill
                Spacer()
                coinPill
                Spacer()
                speedPill
            }
            .padding(.horizontal, 14)
            .padding(.top, 56)

            if gameState.showLevelUp {
                HStack {
                    Spacer()
                    levelUpBadge
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Spacer()

            // ── Saver warning ────────────────────────────────────
            if gameState.showSaverWarning {
                Text("⚠️  LIFE SAVER USED")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.15, blue: 0.4))
                    .shadow(color: Color(red: 1.0, green: 0.0, blue: 0.3).opacity(0.9), radius: 14)
                    .tracking(2)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.bottom, 10)
            }

            // ── Near-miss flash ──────────────────────────────────
            if gameState.showNearMiss {
                nearMissLabel
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            if gameState.showGoalComplete {
                goalCompleteLabel
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Active power-up timers ───────────────────────────
            if !gameState.activePowerUps.isEmpty {
                powerUpBars
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            compactStatusBar.padding(.bottom, 24)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: gameState.comboCount)
        .animation(.easeInOut(duration: 0.3), value: gameState.showNearMiss)
        .animation(.easeInOut(duration: 0.3), value: gameState.showSaverWarning)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: gameState.showLevelUp)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: gameState.showGoalComplete)
        .animation(.spring(response: 0.4), value: gameState.activePowerUps.count)
    }

    // MARK: - Top Pills

    private var scorePill: some View {
        VStack(alignment: .leading, spacing: 2) {
                Text("SCORE")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
                .tracking(2)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(gameState.score)")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 0.55, green: 0.0, blue: 1.0)],
                        startPoint: .leading, endPoint: .trailing))
                    .shadow(color: Color(red: 0, green: 0.9, blue: 1).opacity(0.7), radius: 10)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: gameState.score)
                if gameState.scoreMultiplier > 1 {
                    Text("×\(gameState.scoreMultiplier)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(multiplierColor)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(multiplierColor.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(hudPill)
    }

    private var coinPill: some View {
        VStack(spacing: 2) {
            Text("COINS")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.45)).tracking(2)
            HStack(spacing: 5) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                Text("\(gameState.coinCount)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.9, blue: 0.0), .orange],
                        startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .yellow.opacity(0.6), radius: 8)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: gameState.coinCount)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(hudPill)
    }

    private var speedPill: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("KM/H")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.45)).tracking(2)
            Text(String(format: "%.0f", gameState.currentSpeed * 3.6))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: speedGradient(gameState.currentSpeed),
                                                 startPoint: .leading, endPoint: .trailing))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5), value: gameState.currentSpeed)
        }
        .padding(.horizontal, 11).padding(.vertical, 8)
        .background(hudPill)
    }

    // MARK: - Combo Badge

    private var levelStrip: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0))
                Text("LEVEL \(gameState.currentLevel.number)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.78))
                    .tracking(2)
                Text(gameState.currentLevel.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .tracking(2)
                Spacer()
                Text(String(format: "%.0f%%", gameState.levelProgress * 100))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 1.0, green: 0.85, blue: 0.0)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(gameState.levelProgress))
                        .animation(.linear(duration: 0.12), value: gameState.levelProgress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(hudPill)
    }

    private var goalStrip: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: gameState.runGoal.isCompleted ? "checkmark.seal.fill" : "target")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(gameState.runGoal.isCompleted ? Color(red: 0.2, green: 1.0, blue: 0.3) : Color(red: 1.0, green: 0.85, blue: 0.0))
                Text(gameState.runGoal.title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
                    .tracking(2)
                Spacer()
                Text("+\(gameState.runGoal.rewardCoins)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0))
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 1.0, green: 0.85, blue: 0.0), Color(red: 0.2, green: 1.0, blue: 0.3)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * CGFloat(gameState.runGoal.progressFraction))
                        .animation(.linear(duration: 0.12), value: gameState.runGoal.progressFraction)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(hudPill)
    }

    private var levelUpBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0))
            VStack(alignment: .leading, spacing: 1) {
                Text("LEVEL \(gameState.currentLevel.number)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.82))
                    .tracking(2)
                Text(gameState.currentLevel.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.0, green: 0.95, blue: 1.0))
                    .tracking(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.42), lineWidth: 1.5)))
    }

    private var comboBadge: some View {
        VStack(spacing: 3) {
            Text("COMBO")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.55)).tracking(4)
            HStack(spacing: 6) {
                ForEach(0..<min(gameState.comboCount, 5), id: \.self) { _ in
                    Circle().fill(multiplierColor).frame(width: 7, height: 7)
                        .shadow(color: multiplierColor.opacity(0.9), radius: 4)
                }
                if gameState.comboCount > 5 {
                    Text("+\(gameState.comboCount - 5)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(multiplierColor)
                }
            }
            Text("×\(gameState.scoreMultiplier)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [multiplierColor, multiplierColor.opacity(0.6)],
                                                 startPoint: .top, endPoint: .bottom))
                .shadow(color: multiplierColor.opacity(0.8), radius: 12)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(multiplierColor.opacity(0.5), lineWidth: 1.5)))
        .padding(.top, 10)
    }

    // MARK: - Power-up Bars

    private var powerUpBars: some View {
        HStack(spacing: 10) {
            ForEach(PowerUpType.allCases, id: \.rawValue) { type in
                if gameState.activePowerUps[type.rawValue] != nil {
                    powerUpBar(type: type)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func powerUpBar(type: PowerUpType) -> some View {
        let remaining = gameState.activePowerUps[type.rawValue] ?? 0
        let fraction = Double(remaining / type.duration)

        return VStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(type.color)
                .shadow(color: type.color.opacity(0.9), radius: 6)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(type.color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(LinearGradient(colors: [type.color, type.color.opacity(0.6)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(max(fraction, 0)))
                        .animation(.linear(duration: 0.1), value: fraction)
                }
            }
            .frame(width: 60, height: 5)

            Text(String(format: "%.1fs", remaining))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(type.color.opacity(0.75))
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(type.color.opacity(0.35), lineWidth: 1)))
    }

    // MARK: - Near Miss & Distance

    private var nearMissLabel: some View {
        Text("NEAR MISS  +\(3 * gameState.scoreMultiplier)")
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(LinearGradient(
                colors: [Color(red: 1.0, green: 0.8, blue: 0.0), Color(red: 1.0, green: 0.3, blue: 0.0)],
                startPoint: .leading, endPoint: .trailing))
            .shadow(color: .orange.opacity(0.9), radius: 14)
            .tracking(2)
            .padding(.bottom, 20)
    }

    private var goalCompleteLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color(red: 0.2, green: 1.0, blue: 0.3))
            Text("GOAL COMPLETE  +\(gameState.runGoal.rewardCoins)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 0.2, green: 1.0, blue: 0.3), Color(red: 1.0, green: 0.85, blue: 0.0)],
                    startPoint: .leading, endPoint: .trailing))
                .tracking(2)
        }
        .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.3).opacity(0.75), radius: 10)
    }

    private var compactStatusBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.25))
            Text(String(format: "%.0f m", gameState.distanceMeters))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.60))
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: gameState.distanceMeters)
            Divider().frame(height: 12).overlay(Color.white.opacity(0.18))
            Text("LV \(gameState.currentLevel.number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.75, green: 0.82, blue: 1.0))
            Text(String(format: "%.0f%%", gameState.levelProgress * 100))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
            Divider().frame(height: 12).overlay(Color.white.opacity(0.18))
            Image(systemName: gameState.runGoal.isCompleted ? "checkmark.seal.fill" : "target")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(gameState.runGoal.isCompleted ? Color(red: 0.3, green: 0.9, blue: 0.45) : Color(red: 1.0, green: 0.78, blue: 0.25))
            Text(gameState.runGoal.progressText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.58))
            if gameState.scoreMultiplier > 1 {
                Divider().frame(height: 12).overlay(Color.white.opacity(0.18))
                Text("×\(gameState.scoreMultiplier)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(multiplierColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)))
    }

    // MARK: - Style Helpers

    private var hudPill: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var multiplierColor: Color {
        switch gameState.scoreMultiplier {
        case 2:  return Color(red: 0.0, green: 0.95, blue: 1.0)
        case 3:  return Color(red: 1.0, green: 0.85, blue: 0.0)
        default: return Color(red: 1.0, green: 0.1, blue: 0.5)
        }
    }

    private func speedGradient(_ spd: Float) -> [Color] {
        if spd < 18 {
            return [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 0.0, green: 0.7, blue: 0.9)]
        } else if spd < 28 {
            return [Color(red: 1.0, green: 0.85, blue: 0.0), Color(red: 1.0, green: 0.4, blue: 0.0)]
        } else {
            return [Color(red: 1.0, green: 0.1, blue: 0.4), Color(red: 1.0, green: 0.0, blue: 0.8)]
        }
    }
}
