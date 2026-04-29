//
//  MenuView.swift
//  apexRunner
//

import SwiftUI

struct MenuView: View {
    var gameState: GameState
    var store = GameProgressStore.shared

    @State private var glowPulse = false
    @State private var subtitleOpacity = 0.0
    @State private var showShop = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.12).opacity(0.88),
                    Color(red: 0.02, green: 0.01, blue: 0.08).opacity(0.70),
                    Color.clear
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Coin balance (top)
                HStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(LinearGradient(colors: [.yellow, .orange],
                                                             startPoint: .top, endPoint: .bottom))
                        Text("\(store.totalCoins)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.9, blue: 0.0), .orange],
                                                             startPoint: .leading, endPoint: .trailing))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.trailing, 20)
                }
                .padding(.top, 56)

                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Text("APEX")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 0.55, green: 0.0, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing))
                        .shadow(color: Color(red: 0.0, green: 0.9, blue: 1.0).opacity(glowPulse ? 0.95 : 0.5),
                                radius: glowPulse ? 28 : 14)
                        .scaleEffect(glowPulse ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: glowPulse)

                    Text("RUNNER")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(
                            colors: [Color(red: 1.0, green: 0.1, blue: 0.6), Color(red: 1.0, green: 0.6, blue: 0.0)],
                            startPoint: .leading, endPoint: .trailing))
                        .shadow(color: Color(red: 1.0, green: 0.1, blue: 0.5).opacity(0.7), radius: 18)

                    Text("3D")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.75, green: 0.75, blue: 0.95))
                        .tracking(12)
                        .padding(.top, 2)
                }
                .padding(.bottom, 20)

                Text("Dodge · Dash · Survive")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.85))
                    .tracking(4)
                    .opacity(subtitleOpacity)

                Spacer().frame(height: 50)

                // Selected skin preview
                HStack(spacing: 8) {
                    Image(systemName: store.selectedSkin.icon)
                        .font(.system(size: 14))
                        .foregroundColor(store.selectedSkin.previewColor)
                    Text(store.selectedSkin.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(store.selectedSkin.previewColor)
                        .tracking(3)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(store.selectedSkin.previewColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.bottom, 20)

                // RUN button
                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    gameState.startGame()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.0, green: 0.85, blue: 1.0), Color(red: 0.45, green: 0.0, blue: 1.0)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: 220, height: 58)
                            .shadow(color: Color(red: 0.0, green: 0.8, blue: 1.0).opacity(0.55), radius: 20)
                        Text("RUN")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white).tracking(6)
                    }
                }

                Spacer().frame(height: 16)

                // SHOP + THEME row
                HStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showShop = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bag.fill").font(.system(size: 14, weight: .bold))
                            Text("SHOP").font(.system(size: 14, weight: .bold, design: .rounded)).tracking(4)
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.0))
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.4), lineWidth: 1))
                    }

                    // Theme toggle: NEON ↔ MINIMAL
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.setTheme(store.selectedTheme == "neon" ? "minimal" : "neon")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: store.selectedTheme == "neon" ? "sparkles" : "circle.grid.2x2.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text(store.selectedTheme == "neon" ? "NEON" : "MINIMAL")
                                .font(.system(size: 12, weight: .bold, design: .rounded)).tracking(2)
                        }
                        .foregroundColor(store.selectedTheme == "neon"
                                         ? Color(red: 0.0, green: 0.95, blue: 1.0)
                                         : Color(red: 0.75, green: 0.75, blue: 0.88))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                }

                Spacer().frame(height: 30)

                if gameState.highScore > 0 {
                    VStack(spacing: 4) {
                        Text("BEST")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.85).opacity(0.7))
                            .tracking(5)
                        Text("\(gameState.highScore)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.85, blue: 0.0), .orange],
                                                             startPoint: .leading, endPoint: .trailing))
                            .shadow(color: .orange.opacity(0.5), radius: 10)
                    }
                    .padding(.bottom, 10)
                }

                Label("Swipe left / right to dodge", systemImage: "hand.draw")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showShop) {
            ShopView(isPresented: $showShop)
        }
        .onAppear {
            glowPulse = true
            withAnimation(.easeIn(duration: 0.8).delay(0.3)) { subtitleOpacity = 1.0 }
        }
    }
}
