//
//  ContentView.swift
//  apexRunner
//

import SwiftUI

struct ContentView: View {
    @State private var gameState = GameState()

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.01, blue: 0.06)
                .ignoresSafeArea()

            if gameState.phase != .menu {
                GameSceneView(gameState: gameState)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Overlay UI based on current phase
            Group {
                switch gameState.phase {
                case .menu:
                    MenuView(gameState: gameState)
                        .transition(.opacity)
                case .playing:
                    HUDView(gameState: gameState)
                        .transition(.opacity)
                case .gameOver:
                    GameOverView(gameState: gameState)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                }
            }
            .animation(.easeInOut(duration: 0.45), value: gameState.phase)
        }
        .ignoresSafeArea()
    }
}
