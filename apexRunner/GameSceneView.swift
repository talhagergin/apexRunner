//
//  GameSceneView.swift
//  apexRunner
//
//  UIViewRepresentable wrapper for SCNView. Coordinator is the GameController.
//

import SwiftUI
import SceneKit

struct GameSceneView: UIViewRepresentable {
    var gameState: GameState

    func makeCoordinator() -> GameController {
        GameController(gameState: gameState)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let ctrl = context.coordinator

        ctrl.setup(scnView: view)

        view.scene = ctrl.scene
        view.delegate = ctrl
        view.backgroundColor = .black
        view.allowsCameraControl = false
        view.showsStatistics = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true

        // Pan gesture for lane switching
        let pan = UIPanGestureRecognizer(
            target: ctrl,
            action: #selector(GameController.handlePan(_:))
        )
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Called whenever gameState (Observable) changes — forward phase transitions
        context.coordinator.handlePhaseChange(gameState.phase)
    }
}
