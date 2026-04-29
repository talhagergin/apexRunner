//
//  GameOverView.swift
//  apexRunner
//

import SwiftUI

struct GameOverView: View {
    var gameState: GameState
    var store = GameProgressStore.shared

    @State private var appeared = false
    @State private var scoreScale: CGFloat = 0.4
    @State private var showShop = false

    var isNewRecord: Bool { gameState.score > 0 && gameState.score == gameState.highScore }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea().opacity(0.85)
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.0, blue: 0.20).opacity(0.9),
                         Color(red: 0.05, green: 0.0, blue: 0.10).opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // GAME OVER title
                    VStack(spacing: 6) {
                        Text("GAME")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(red: 1.0, green: 0.15, blue: 0.45), Color(red: 1.0, green: 0.0, blue: 0.7)],
                                startPoint: .leading, endPoint: .trailing))
                            .shadow(color: Color(red: 1.0, green: 0.0, blue: 0.5).opacity(0.8), radius: 22)
                        Text("OVER")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(
                                colors: [Color(red: 1.0, green: 0.0, blue: 0.7), Color(red: 0.55, green: 0.0, blue: 1.0)],
                                startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .purple.opacity(0.7), radius: 20)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -30)

                    // Score card
                    VStack(spacing: 14) {
                        if isNewRecord {
                            Text("🏆 NEW RECORD")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                                 startPoint: .leading, endPoint: .trailing))
                                .tracking(4).shadow(color: .yellow.opacity(0.8), radius: 10)
                        }

                        VStack(spacing: 4) {
                            Text("SCORE").font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.45)).tracking(5)
                            Text("\(gameState.score)")
                                .font(.system(size: 60, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 0.55, green: 0.0, blue: 1.0)],
                                    startPoint: .leading, endPoint: .trailing))
                                .shadow(color: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.6), radius: 16)
                                .scaleEffect(scoreScale)
                        }

                        HStack(spacing: 24) {
                            statCell(label: "DISTANCE", value: String(format: "%.0fm", gameState.distanceMeters))
                            Divider().frame(height: 30).overlay(Color.white.opacity(0.2))
                            statCell(label: "LEVEL", value: "\(gameState.currentLevel.number)")
                            Divider().frame(height: 30).overlay(Color.white.opacity(0.2))
                            statCell(label: "BEST", value: "\(gameState.highScore)")
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial)
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.4), .purple.opacity(0.3)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                    )
                    .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 40)

                    // Coins earned this run
                    if gameState.coinCount > 0 {
                        coinsEarnedCard
                            .opacity(appeared ? 1 : 0)
                    }

                    // Buttons
                    VStack(spacing: 12) {
                        // Retry
                        Button {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            gameState.startGame()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color(red: 0.0, green: 0.85, blue: 1.0), Color(red: 0.4, green: 0.0, blue: 1.0)],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: 200, height: 54)
                                    .shadow(color: Color(red: 0.0, green: 0.7, blue: 1.0).opacity(0.5), radius: 18)
                                Label("TRY AGAIN", systemImage: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white).tracking(2)
                            }
                        }

                        // Shop
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showShop = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bag.fill")
                                Text("SHOP")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0)).tracking(3)
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .background(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.3), lineWidth: 1))
                        }

                        // Menu
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation { gameState.phase = .menu }
                        } label: {
                            Text("MAIN MENU")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.50)).tracking(3)
                        }
                    }
                    .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 30)
                }
                .padding(.top, 60)
            }
        }
        .fullScreenCover(isPresented: $showShop) {
            ShopView(isPresented: $showShop)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75).delay(0.15)) {
                appeared = true; scoreScale = 1.0
            }
        }
    }

    // MARK: - Coins Earned Card

    private var coinsEarnedCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.yellow.opacity(0.15)).frame(width: 50, height: 50)
                Image(systemName: "circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .yellow.opacity(0.9), radius: 8)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("COINS EARNED")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5)).tracking(3)
                Text("+\(gameState.coinCount)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.9, blue: 0.0), .orange],
                                                     startPoint: .leading, endPoint: .trailing))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("TOTAL")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4)).tracking(3)
                Text("\(GameProgressStore.shared.totalCoins)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.45)).tracking(3)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
