//
//  GameController.swift
//  apexRunner
//
//  SceneKit game engine. Straight road, multi-theme, fixed city buildings.
//

import SceneKit
import UIKit

final class GameController: NSObject, SCNSceneRendererDelegate {

    // MARK: - Constants
    private let laneXPositions: [Float] = [-2.0, 0.0, 2.0]
    private let segmentLength: Float = 30.0
    private let lookaheadDistance: Float = 210.0
    private let cleanupDistance: Float = 60.0
    private let baseSpeed: Float = 12.0
    private let laneChangeDuration: TimeInterval = 0.17
    private let hitThresholdX: Float = 0.78
    private let hitThresholdZ: Float = 1.05
    private let nearMissX: Float = 1.40
    private let nearMissZ: Float = 1.70

    // MARK: - Dependencies
    unowned var gameState: GameState
    var scene: SCNScene!
    weak var scnView: SCNView?

    // MARK: - Game State
    private var isRunning = false
    private var isDead = false
    private var currentPhase: GamePhase = .menu
    private var currentLane: Int = 1
    private var currentSpeed: Float = 12.0
    private var runBaseSpeed: Float = 12.0
    private var gameTime: Float = 0
    private var totalDistance: Float = 0
    private var lastUpdateTime: TimeInterval = 0
    private var nextSegmentZ: Float = 0
    private var lastHapticScore: Int = 0
    private var coinPickupRadius: Float = 1.0
    private var saverUsed = false

    // MARK: - Gesture
    private var gestureStartX: CGFloat = 0
    private var gestureFired = false

    // MARK: - Scene Nodes
    private var runnerNode: SCNNode!
    private var characterNode: SCNNode!
    private var bodyContainer: SCNNode!
    private var cameraNode: SCNNode!
    private var cameraLookTarget: SCNNode!
    private var leftArmPivot: SCNNode!
    private var rightArmPivot: SCNNode!
    private var leftLegPivot: SCNNode!
    private var rightLegPivot: SCNNode!

    // Character materials for skin support
    private var charBodyMat: SCNMaterial!
    private var charAccentMat: SCNMaterial!
    private var charAltMat: SCNMaterial!

    // Power-up aura nodes
    private var shieldAuraNode: SCNNode?
    private var boostTrailNode: SCNNode?
    private var toxinAuraNode: SCNNode?

    // Object pools
    private var segments: [SCNNode] = []
    private var obstacles: [SCNNode] = []
    private var coins: [SCNNode] = []
    private var powerUpNodes: [SCNNode] = []

    // MARK: - Init
    init(gameState: GameState) {
        self.gameState = gameState
        super.init()
        buildScene()
    }

    // MARK: - Theme Helper

    private var isMinimal: Bool { GameProgressStore.shared.selectedTheme == "minimal" }

    // MARK: - Scene Construction

    private func buildScene() {
        scene = SCNScene()
        applyThemeToScene()
        setupLighting()
        setupStarfield()
        setupHorizonGlow()
        setupCharacter()
        setupCamera()
    }

    func setup(scnView: SCNView) { self.scnView = scnView }

    private func applyThemeToScene() {
        if isMinimal {
            scene.background.contents = UIColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1.0)
            scene.fogStartDistance = 55
            scene.fogEndDistance = 100
            scene.fogColor = UIColor(red: 0.09, green: 0.09, blue: 0.12, alpha: 1.0)
        } else {
            scene.background.contents = UIColor(red: 0.04, green: 0.02, blue: 0.10, alpha: 1.0)
            scene.fogStartDistance = 45
            scene.fogEndDistance = 85
            scene.fogColor = UIColor(red: 0.06, green: 0.01, blue: 0.16, alpha: 1.0)
        }
        if let cam = cameraNode?.camera {
            cam.bloomIntensity = isMinimal ? 0.3 : 1.3
            cam.bloomThreshold = isMinimal ? 0.92 : 0.72
        }
    }

    // MARK: - Lighting

    private func setupLighting() {
        let ambNode = SCNNode(); let amb = SCNLight()
        amb.type = .ambient
        amb.color = isMinimal
            ? UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0)
            : UIColor(red: 0.06, green: 0.02, blue: 0.18, alpha: 1.0)
        amb.intensity = isMinimal ? 280 : 160
        ambNode.light = amb; scene.rootNode.addChildNode(ambNode)

        let mainNode = SCNNode(); let main = SCNLight()
        main.type = .directional
        main.color = isMinimal
            ? UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
            : UIColor(red: 0.85, green: 0.75, blue: 1.0, alpha: 1.0)
        main.intensity = isMinimal ? 900 : 750
        main.castsShadow = true; main.shadowRadius = 4
        main.shadowSampleCount = 4; main.shadowMode = .deferred
        main.shadowColor = UIColor(white: 0, alpha: 0.55)
        mainNode.light = main
        mainNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 8, 0)
        scene.rootNode.addChildNode(mainNode)

        if !isMinimal {
            let rimNode = SCNNode(); let rim = SCNLight()
            rim.type = .directional
            rim.color = UIColor(red: 1.0, green: 0.15, blue: 0.6, alpha: 1.0)
            rim.intensity = 380; rimNode.light = rim
            rimNode.eulerAngles = SCNVector3(Float.pi / 3.5, Float.pi, 0)
            scene.rootNode.addChildNode(rimNode)
        }
    }

    // MARK: - Starfield

    private func setupStarfield() {
        let count = isMinimal ? 60 : 140
        for _ in 0..<count {
            let sphere = SCNSphere(radius: CGFloat.random(in: 0.02...0.07))
            sphere.segmentCount = 4
            let mat = SCNMaterial()
            let br = Float.random(in: 0.65...1.0)
            if isMinimal {
                mat.emission.contents = UIColor(white: CGFloat(br), alpha: 1.0)
                mat.emission.intensity = CGFloat.random(in: 1.5...3.5)
            } else {
                mat.emission.contents = UIColor(red: CGFloat(br), green: CGFloat(br * 0.7 + 0.3), blue: 1.0, alpha: 1.0)
                mat.emission.intensity = CGFloat.random(in: 2.5...6.0)
            }
            sphere.materials = [mat]
            let n = SCNNode(geometry: sphere)
            n.position = SCNVector3(Float.random(in: -90...90), Float.random(in: 8...85), Float.random(in: -220...10))
            scene.rootNode.addChildNode(n)
        }
    }

    private func setupHorizonGlow() {
        guard !isMinimal else { return }  // No horizon glow in minimal theme
        func plane(w: CGFloat, h: CGFloat, z: Float, y: Float, r: CGFloat, g: CGFloat, b: CGFloat, i: CGFloat) {
            let geom = SCNBox(width: w, height: h, length: 1, chamferRadius: 0)
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.clear
            mat.emission.contents = UIColor(red: r, green: g, blue: b, alpha: 1.0)
            mat.emission.intensity = i; mat.isDoubleSided = true
            geom.materials = [mat]
            let n = SCNNode(geometry: geom); n.position = SCNVector3(0, y, z)
            scene.rootNode.addChildNode(n)
        }
        plane(w: 220, h: 40, z: -95, y: 8,  r: 0.55, g: 0.0, b: 0.9, i: 1.2)
        plane(w: 220, h: 4,  z: -92, y: 0.5, r: 1.0, g: 0.1, b: 0.55, i: 0.9)
    }

    // MARK: - Character

    private func setupCharacter() {
        runnerNode = SCNNode()
        scene.rootNode.addChildNode(runnerNode)

        characterNode = SCNNode()
        characterNode.position = SCNVector3(laneXPositions[1], 0, 0)
        runnerNode.addChildNode(characterNode)

        bodyContainer = SCNNode()
        characterNode.addChildNode(bodyContainer)

        buildCharacterGeometry()
        startRunningAnimations()
    }

    private func buildCharacterGeometry() {
        charBodyMat = SCNMaterial()
        charBodyMat.lightingModel = .physicallyBased
        charBodyMat.metalness.contents = CGFloat(0.75)
        charBodyMat.roughness.contents = CGFloat(0.25)

        charAccentMat = SCNMaterial()
        charAccentMat.lightingModel = .physicallyBased
        charAccentMat.metalness.contents = CGFloat(1.0)
        charAccentMat.roughness.contents = CGFloat(0.0)

        charAltMat = SCNMaterial()
        charAltMat.lightingModel = .physicallyBased
        charAltMat.metalness.contents = CGFloat(1.0)
        charAltMat.roughness.contents = CGFloat(0.0)

        applySkin()

        let torsoGeom = SCNBox(width: 0.70, height: 1.0, length: 0.40, chamferRadius: 0.08)
        torsoGeom.materials = [charBodyMat]
        let torsoNode = SCNNode(geometry: torsoGeom)
        torsoNode.position = SCNVector3(0, 1.30, 0)
        bodyContainer.addChildNode(torsoNode)

        let accentGeom = SCNBox(width: 0.72, height: 0.10, length: 0.42, chamferRadius: 0.04)
        accentGeom.materials = [charAccentMat]
        let accentNode = SCNNode(geometry: accentGeom)
        accentNode.position = SCNVector3(0, 0.18, 0)
        torsoNode.addChildNode(accentNode)

        let headGeom = SCNBox(width: 0.56, height: 0.56, length: 0.46, chamferRadius: 0.10)
        headGeom.materials = [charBodyMat]
        let headNode = SCNNode(geometry: headGeom)
        headNode.position = SCNVector3(0, 2.10, 0)
        bodyContainer.addChildNode(headNode)

        let visorGeom = SCNBox(width: 0.35, height: 0.10, length: 0.47, chamferRadius: 0.03)
        visorGeom.materials = [charAccentMat]
        let visorNode = SCNNode(geometry: visorGeom)
        visorNode.position = SCNVector3(0, 2.10, 0)
        bodyContainer.addChildNode(visorNode)

        leftArmPivot  = makeArmNode(x: -0.52, bodyMat: charBodyMat, accentMat: charAltMat)
        rightArmPivot = makeArmNode(x:  0.52, bodyMat: charBodyMat, accentMat: charAltMat)
        bodyContainer.addChildNode(leftArmPivot)
        bodyContainer.addChildNode(rightArmPivot)

        leftLegPivot  = makeLegNode(x: -0.20, bodyMat: charBodyMat, accentMat: charAccentMat)
        rightLegPivot = makeLegNode(x:  0.20, bodyMat: charBodyMat, accentMat: charAccentMat)
        bodyContainer.addChildNode(leftLegPivot)
        bodyContainer.addChildNode(rightLegPivot)
    }

    func applySkin() {
        let skin = GameProgressStore.shared.selectedSkin
        charBodyMat.diffuse.contents = UIColor(red: skin.bodyR, green: skin.bodyG, blue: skin.bodyB, alpha: 1)
        charBodyMat.emission.contents = UIColor(red: skin.emissionR, green: skin.emissionG, blue: skin.emissionB, alpha: 1)
        charBodyMat.emission.intensity = isMinimal ? 0.5 : 1.8
        charAccentMat.diffuse.contents = UIColor.clear
        charAccentMat.emission.contents = UIColor(red: skin.accentR, green: skin.accentG, blue: skin.accentB, alpha: 1)
        charAccentMat.emission.intensity = isMinimal ? 2.0 : 6.0
        charAltMat.diffuse.contents = UIColor.clear
        charAltMat.emission.contents = UIColor(red: skin.altR, green: skin.altG, blue: skin.altB, alpha: 1)
        charAltMat.emission.intensity = isMinimal ? 1.5 : 5.0
    }

    private func makeArmNode(x: Float, bodyMat: SCNMaterial, accentMat: SCNMaterial) -> SCNNode {
        let pivot = SCNNode(); pivot.position = SCNVector3(x, 1.65, 0)
        let g = SCNBox(width: 0.23, height: 0.65, length: 0.23, chamferRadius: 0.05)
        g.materials = [bodyMat]
        let gn = SCNNode(geometry: g); gn.position = SCNVector3(0, -0.325, 0)
        pivot.addChildNode(gn)
        let a = SCNBox(width: 0.24, height: 0.07, length: 0.24, chamferRadius: 0.03)
        a.materials = [accentMat]
        let an = SCNNode(geometry: a); an.position = SCNVector3(0, -0.12, 0)
        pivot.addChildNode(an); return pivot
    }

    private func makeLegNode(x: Float, bodyMat: SCNMaterial, accentMat: SCNMaterial) -> SCNNode {
        let pivot = SCNNode(); pivot.position = SCNVector3(x, 0.80, 0)
        let g = SCNBox(width: 0.28, height: 0.82, length: 0.28, chamferRadius: 0.06)
        g.materials = [bodyMat]
        let gn = SCNNode(geometry: g); gn.position = SCNVector3(0, -0.41, 0)
        pivot.addChildNode(gn)
        let s = SCNBox(width: 0.29, height: 0.07, length: 0.29, chamferRadius: 0.03)
        s.materials = [accentMat]
        let sn = SCNNode(geometry: s); sn.position = SCNVector3(0, -0.16, 0)
        pivot.addChildNode(sn); return pivot
    }

    private func startRunningAnimations() {
        let angle: CGFloat = 0.65; let step: TimeInterval = 0.22
        func fwd() -> SCNAction {
            let a = SCNAction.rotateTo(x: angle, y: 0, z: 0, duration: step)
            a.timingMode = .easeInEaseOut; return a
        }
        func bwd() -> SCNAction {
            let a = SCNAction.rotateTo(x: -angle, y: 0, z: 0, duration: step)
            a.timingMode = .easeInEaseOut; return a
        }
        [leftArmPivot, rightArmPivot, leftLegPivot, rightLegPivot, bodyContainer]
            .compactMap { $0 }.forEach { $0.removeAllActions() }
        leftLegPivot.runAction(SCNAction.repeatForever(SCNAction.sequence([fwd(), bwd()])))
        rightLegPivot.runAction(SCNAction.repeatForever(SCNAction.sequence([bwd(), fwd()])))
        leftArmPivot.runAction(SCNAction.repeatForever(SCNAction.sequence([bwd(), fwd()])))
        rightArmPivot.runAction(SCNAction.repeatForever(SCNAction.sequence([fwd(), bwd()])))
        let up = SCNAction.moveBy(x: 0, y: 0.10, z: 0, duration: step)
        let dn = SCNAction.moveBy(x: 0, y: -0.10, z: 0, duration: step)
        up.timingMode = .easeInEaseOut; dn.timingMode = .easeInEaseOut
        bodyContainer.runAction(SCNAction.repeatForever(SCNAction.sequence([up, dn])))
    }

    // MARK: - Skills

    private func applySkills() {
        let store = GameProgressStore.shared
        coinPickupRadius = store.hasMagnet ? 2.8 : 1.0
        runBaseSpeed     = store.hasHeadstart ? baseSpeed + 5 : baseSpeed
        currentSpeed     = runBaseSpeed
        saverUsed = false
    }

    // MARK: - Camera

    private func setupCamera() {
        cameraLookTarget = SCNNode()
        cameraLookTarget.position = SCNVector3(0, 1.5, -8)
        scene.rootNode.addChildNode(cameraLookTarget)

        let cam = SCNCamera()
        cam.fieldOfView = 72; cam.zNear = 0.1; cam.zFar = 200
        cam.wantsHDR = true
        cam.bloomIntensity = isMinimal ? 0.3 : 1.3
        cam.bloomBlurRadius = 14
        cam.bloomThreshold = isMinimal ? 0.92 : 0.72
        cam.motionBlurIntensity = 0.25

        cameraNode = SCNNode(); cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 8, 14)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func updateCamera() {
        // Character's world X = runnerNode.x (always 0) + characterNode's local X
        let charX = characterNode.presentation.position.x
        let charZ = runnerNode.position.z
        let s: Float = 0.065
        let nx = cameraNode.position.x + (charX * 0.35 - cameraNode.position.x) * s
        let ny = cameraNode.position.y + (8.0 - cameraNode.position.y) * s
        let nz = cameraNode.position.z + (charZ + 14.0 - cameraNode.position.z) * s * 2.5
        cameraNode.position = SCNVector3(nx, ny, nz)
        cameraLookTarget.position = SCNVector3(charX * 0.2, 1.5, charZ - 8)
        let lookAt = SCNLookAtConstraint(target: cameraLookTarget)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
    }

    // MARK: - Road Segment

    private func createSegment(atZ z: Float) -> SCNNode {
        let root = SCNNode()
        root.position = SCNVector3(0, 0, z)   // STRAIGHT: always at x=0

        let roadW: CGFloat = 6.6
        let segL = CGFloat(segmentLength)

        // Road surface
        let roadColor = isMinimal
            ? UIColor(red: 0.14, green: 0.14, blue: 0.18, alpha: 1.0)
            : UIColor(red: 0.07, green: 0.04, blue: 0.14, alpha: 1.0)
        let roadGeom = SCNBox(width: roadW, height: 0.30, length: segL, chamferRadius: 0)
        roadGeom.materials = [makeMat(diffuse: roadColor,
                                       emission: roadColor.withAlphaComponent(0.3),
                                       emissionIntensity: 0.5, metalness: 0.5, roughness: 0.5)]
        let roadNode = SCNNode(geometry: roadGeom)
        roadNode.position = SCNVector3(0, -0.15, 0)
        root.addChildNode(roadNode)

        // Edge strips
        if isMinimal {
            addEdge(to: root, x: -Float(roadW)/2 + 0.07, length: segL, r: 0.85, g: 0.85, b: 0.90, intensity: 3.0)
            addEdge(to: root, x:  Float(roadW)/2 - 0.07, length: segL, r: 0.85, g: 0.85, b: 0.90, intensity: 3.0)
        } else {
            addEdge(to: root, x: -Float(roadW)/2 + 0.07, length: segL, r: 0.85, g: 0.10, b: 0.45, intensity: 3.4)
            addEdge(to: root, x:  Float(roadW)/2 - 0.07, length: segL, r: 0.0, g: 0.62, b: 0.78,  intensity: 3.4)
        }

        // Lane dividers
        let divColor = isMinimal
            ? UIColor(red: 0.45, green: 0.45, blue: 0.55, alpha: 1.0)
            : UIColor(red: 0.65, green: 0.0, blue: 1.0, alpha: 1.0)
        let divIntensity: CGFloat = isMinimal ? 1.5 : 3.0
        for xDiv: Float in [-2.0, 2.0] {
            let dg = SCNBox(width: 0.05, height: 0.32, length: segL, chamferRadius: 0)
            dg.materials = [makeMat(diffuse: UIColor.clear, emission: divColor,
                                     emissionIntensity: divIntensity, metalness: 1.0, roughness: 0.0)]
            let dn = SCNNode(geometry: dg); dn.position = SCNVector3(xDiv, 0, 0)
            root.addChildNode(dn)
        }

        // Horizontal grid lines (neon only)
        if !isMinimal {
            var gz: Float = -(segmentLength/2) + 3.0
            while gz < segmentLength/2 {
                let hg = SCNBox(width: roadW, height: 0.31, length: 0.055, chamferRadius: 0)
                hg.materials = [makeMat(diffuse: UIColor.clear,
                                         emission: UIColor(red: 0.55, green: 0.0, blue: 0.90, alpha: 1.0),
                                         emissionIntensity: 2.5, metalness: 1.0, roughness: 0.0)]
                let hn = SCNNode(geometry: hg); hn.position = SCNVector3(0, 0, gz)
                root.addChildNode(hn); gz += 3.0
            }
        } else {
            // Minimal: simple dashed center line
            var gz: Float = -(segmentLength/2) + 2.0
            while gz < segmentLength/2 {
                let hg = SCNBox(width: 0.06, height: 0.31, length: 1.5, chamferRadius: 0)
                hg.materials = [makeMat(diffuse: UIColor.clear,
                                         emission: UIColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1.0),
                                         emissionIntensity: 2.0, metalness: 1.0, roughness: 0.0)]
                let hn = SCNNode(geometry: hg); hn.position = SCNVector3(0, 0, gz)
                root.addChildNode(hn); gz += 4.0
            }
        }

        // Neon arch (neon only)
        if !isMinimal { root.addChildNode(makeArch()) }

        // City buildings (both themes, different styles)
        addCityscape(to: root, side: -1)
        addCityscape(to: root, side:  1)

        return root
    }

    private func addEdge(to parent: SCNNode, x: Float, length: CGFloat,
                         r: CGFloat, g: CGFloat, b: CGFloat, intensity: CGFloat) {
        let geom = SCNBox(width: 0.12, height: 0.35, length: length, chamferRadius: 0)
        geom.materials = [makeMat(diffuse: UIColor.clear,
                                   emission: UIColor(red: r, green: g, blue: b, alpha: 1.0),
                                   emissionIntensity: intensity, metalness: 1.0, roughness: 0.0)]
        let n = SCNNode(geometry: geom); n.position = SCNVector3(x, 0, 0)
        parent.addChildNode(n)
    }

    // MARK: - Neon Arch

    private func makeArch() -> SCNNode {
        let root = SCNNode()
        let archColors: [(CGFloat, CGFloat, CGFloat)] = [
            (1.0, 0.10, 0.60), (0.0, 0.88, 1.0), (0.65, 0.0, 1.0), (0.0, 1.0, 0.55)
        ]
        let c = archColors[Int.random(in: 0..<archColors.count)]
        let mat = makeMat(diffuse: UIColor.clear,
                          emission: UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0),
                          emissionIntensity: 7.0, metalness: 1.0, roughness: 0.0)
        let h: CGFloat = 8.0; let w: CGFloat = 0.14
        func pillar(_ x: Float) -> SCNNode {
            let g = SCNBox(width: w, height: h, length: w, chamferRadius: 0.05)
            g.materials = [mat]; let n = SCNNode(geometry: g)
            n.position = SCNVector3(x, Float(h/2), 0); return n
        }
        root.addChildNode(pillar(-3.6)); root.addChildNode(pillar(3.6))
        let bg = SCNBox(width: 7.34, height: w, length: w, chamferRadius: 0.05)
        bg.materials = [mat]; let bn = SCNNode(geometry: bg)
        bn.position = SCNVector3(0, Float(h), 0); root.addChildNode(bn)
        let flicker = SCNAction.customAction(duration: 2.0) { node, elapsed in
            let t = Float(elapsed); let f = CGFloat(0.85 + 0.15 * sin(t * Float.pi * 3.0))
            node.enumerateChildNodes { child, _ in
                child.geometry?.firstMaterial?.emission.intensity = 7.0 * f
            }
        }
        root.runAction(SCNAction.repeatForever(flicker))
        return root
    }

    // MARK: - City Buildings (individual boxes, not solid walls)

    private func addCityscape(to parent: SCNNode, side: Float) {
        // Place 3-5 individual building boxes per segment side
        let buildingCount = isMinimal ? Int.random(in: 3...5) : Int.random(in: 2...3)
        let spacing = segmentLength / Float(buildingCount)

        let neonColors: [(CGFloat, CGFloat, CGFloat)] = [
            (0.0, 0.42, 0.58), (0.48, 0.16, 0.68), (0.72, 0.12, 0.34), (0.10, 0.62, 0.38)
        ]
        let minimalColors: [(CGFloat, CGFloat, CGFloat)] = [
            (0.55, 0.55, 0.65), (0.45, 0.45, 0.55), (0.65, 0.65, 0.75), (0.50, 0.50, 0.60)
        ]

        for i in 0..<buildingCount {
            let bw = Float.random(in: 3.0...6.5)
            let bh = isMinimal ? Float.random(in: 5...20) : Float.random(in: 4...14)
            let bd = Float.random(in: 2.5...5.5)
            let xOff = side * (isMinimal ? Float.random(in: 9.0...14.0) : Float.random(in: 12.0...17.0))
            let zOff = -(segmentLength / 2) + spacing * Float(i) + Float.random(in: 0...(spacing * 0.7))

            let palette = isMinimal ? minimalColors : neonColors
            let c = palette[Int.random(in: 0..<palette.count)]
            let accentColor = UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0)

            // Dark body
            let bodyGeom = SCNBox(width: CGFloat(bw), height: CGFloat(bh), length: CGFloat(bd), chamferRadius: 0)
            let bodyMat = SCNMaterial()
            bodyMat.lightingModel = .physicallyBased
            bodyMat.diffuse.contents = isMinimal
                ? UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1.0)
                : UIColor(red: 0.04, green: 0.02, blue: 0.10, alpha: 1.0)
            bodyMat.emission.contents = accentColor
            bodyMat.emission.intensity = isMinimal ? 0.08 : 0.18
            bodyMat.metalness.contents = CGFloat(0.3)
            bodyMat.roughness.contents = CGFloat(0.7)
            bodyGeom.materials = [bodyMat]
            let building = SCNNode(geometry: bodyGeom)
            building.position = SCNVector3(xOff, bh / 2, zOff)
            parent.addChildNode(building)

            // Neon cap on top
            let capGeom = SCNBox(width: CGFloat(bw + 0.2), height: 0.18, length: CGFloat(bd + 0.2), chamferRadius: 0)
            capGeom.materials = [makeMat(diffuse: UIColor.clear, emission: accentColor,
                                          emissionIntensity: isMinimal ? 2.0 : 2.4,
                                          metalness: 1.0, roughness: 0.0)]
            let cap = SCNNode(geometry: capGeom)
            cap.position = SCNVector3(xOff, bh + 0.09, zOff)
            parent.addChildNode(cap)

            // 1-3 window lights
            for _ in 0..<(isMinimal ? Int.random(in: 1...3) : Int.random(in: 1...2)) {
                let wx = xOff + Float.random(in: -bw * 0.3...bw * 0.3)
                let wy = Float.random(in: bh * 0.2...bh * 0.75)
                let wGeom = SCNBox(width: 0.55, height: 0.35, length: 0.12, chamferRadius: 0.04)
                let wMat = SCNMaterial()
                wMat.emission.contents = accentColor
                let wIntensityLow: CGFloat  = isMinimal ? 1.5 : 1.2
                let wIntensityHigh: CGFloat = isMinimal ? 3.0 : 2.4
                wMat.emission.intensity = CGFloat.random(in: wIntensityLow...wIntensityHigh)
                wMat.diffuse.contents = UIColor.clear
                wGeom.materials = [wMat]
                let wNode = SCNNode(geometry: wGeom)
                wNode.position = SCNVector3(wx, wy, zOff)
                parent.addChildNode(wNode)
            }
        }
    }

    // MARK: - Obstacles

    private func createObstacle(lane: Int, atZ z: Float) -> SCNNode {
        let root = SCNNode()
        root.position = SCNVector3(laneXPositions[lane], 0, z)  // straight: direct lane position

        let neonPalette: [(UIColor, CGFloat)] = [
            (UIColor(red: 0.95, green: 0.18, blue: 0.28, alpha: 1.0), 5.2),
            (UIColor(red: 0.15, green: 0.72, blue: 0.95, alpha: 1.0), 5.0),
            (UIColor(red: 0.95, green: 0.72, blue: 0.18, alpha: 1.0), 4.8),
            (UIColor(red: 0.66, green: 0.28, blue: 0.95, alpha: 1.0), 5.0)
        ]
        let minimalPalette: [(UIColor, CGFloat)] = [
            (UIColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1.0), 3.0),
            (UIColor(red: 0.15, green: 0.40, blue: 0.9, alpha: 1.0), 3.0),
            (UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0), 2.5),
            (UIColor(red: 0.9, green: 0.55, blue: 0.1, alpha: 1.0), 3.0)
        ]
        let palette = isMinimal ? minimalPalette : neonPalette
        let (color, intensity) = palette[Int.random(in: 0..<palette.count)]

        let mat = makeMat(diffuse: color.withAlphaComponent(isMinimal ? 0.5 : 0.42),
                          emission: color, emissionIntensity: intensity,
                          metalness: 0.8, roughness: isMinimal ? 0.4 : 0.1)

        let type = Int.random(in: 0...3)
        let geom: SCNGeometry; let vHeight: Float
        switch type {
        case 0:  geom = SCNBox(width: 1.7, height: 2.2, length: 1.1, chamferRadius: 0.12); vHeight = 2.2
        case 1:  geom = SCNBox(width: 0.80, height: 3.5, length: 0.80, chamferRadius: 0.12); vHeight = 3.5
        case 2:  geom = SCNPyramid(width: 1.7, height: 2.8, length: 1.7); vHeight = 2.8
        default: geom = SCNBox(width: 1.6, height: 1.6, length: 1.6, chamferRadius: 0.14); vHeight = 1.6
        }
        geom.materials = [mat]
        let meshNode = SCNNode(geometry: geom)
        meshNode.position = SCNVector3(0, vHeight / 2, 0)

        if type == 2 {
            meshNode.runAction(SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0.4, duration: 2.8)
            ))
        } else {
            let pulse = SCNAction.customAction(duration: 1.0) { node, elapsed in
                let t = Float(elapsed)
                let factor = CGFloat(0.6 + 0.4 * sin(t * Float.pi))
                node.geometry?.firstMaterial?.emission.intensity = intensity * factor
            }
            meshNode.runAction(SCNAction.repeatForever(pulse))
        }
        root.addChildNode(meshNode)

        // Warning arrow
        let warnColor = isMinimal
            ? UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1.0)
            : UIColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 1.0)
        let warnGeom = SCNPyramid(width: 0.45, height: 0.55, length: 0.45)
        warnGeom.materials = [makeMat(diffuse: UIColor.clear, emission: warnColor,
                                       emissionIntensity: isMinimal ? 5.0 : 10.0,
                                       metalness: 1.0, roughness: 0.0)]
        let warnNode = SCNNode(geometry: warnGeom)
        warnNode.eulerAngles = SCNVector3(Float.pi, 0, 0)
        warnNode.position = SCNVector3(0, vHeight + 1.8, 0)
        let wb = SCNAction.sequence([SCNAction.moveBy(x: 0, y: 0.35, z: 0, duration: 0.4),
                                      SCNAction.moveBy(x: 0, y: -0.35, z: 0, duration: 0.4)])
        warnNode.runAction(SCNAction.repeatForever(wb))
        root.addChildNode(warnNode)

        // Ground ring
        let ringGeom = SCNTorus(ringRadius: 0.95, pipeRadius: 0.04)
        ringGeom.materials = [makeMat(diffuse: UIColor.clear, emission: color,
                                       emissionIntensity: isMinimal ? 2.5 : 4.5,
                                       metalness: 1.0, roughness: 0.0)]
        let ringNode = SCNNode(geometry: ringGeom)
        ringNode.position = SCNVector3(0, 0.03, 0)
        root.addChildNode(ringNode)

        return root
    }

    // MARK: - Coins

    private func createCoin() -> SCNNode {
        let root = SCNNode()
        let goldColor = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
        let torus = SCNTorus(ringRadius: 0.30, pipeRadius: 0.07)
        torus.materials = [makeMat(diffuse: goldColor, emission: goldColor,
                                    emissionIntensity: isMinimal ? 2.5 : 5.5,
                                    metalness: 0.95, roughness: 0.05)]
        let mn = SCNNode(geometry: torus); mn.eulerAngles = SCNVector3(Float.pi/2, 0, 0)
        root.addChildNode(mn)
        root.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi*2, z: 0, duration: 1.2)))
        let up = SCNAction.moveBy(x: 0, y: 0.18, z: 0, duration: 0.6)
        let dn = SCNAction.moveBy(x: 0, y: -0.18, z: 0, duration: 0.6)
        up.timingMode = .easeInEaseOut; dn.timingMode = .easeInEaseOut
        root.runAction(SCNAction.repeatForever(SCNAction.sequence([up, dn])))
        return root
    }

    private func spawnCoins(centerZ: Float) {
        guard Int.random(in: 0...2) != 0 else { return }
        let pattern = Int.random(in: 0...2)
        func addCoin(lane: Int, z: Float) {
            let coin = createCoin()
            coin.position = SCNVector3(laneXPositions[lane], 1.2, z)
            scene.rootNode.addChildNode(coin); coins.append(coin)
        }
        switch pattern {
        case 0:
            let lane = Int.random(in: 0...2)
            for i in 0..<4 { addCoin(lane: lane, z: centerZ + Float(i-2)*3.5) }
        case 1:
            let zOff: [Float] = [-5, 0, 5]
            for (i, lane) in [0,1,2].enumerated() { addCoin(lane: lane, z: centerZ + zOff[i]) }
        default:
            let start = Int.random(in: 0...1)
            for i in 0..<5 { addCoin(lane: (start+i)%2==0 ? 0 : 2, z: centerZ + Float(i-2)*3.0) }
        }
    }

    // MARK: - Power-Ups

    private func createPowerUpNode(type: PowerUpType) -> SCNNode {
        let root = SCNNode(); root.name = type.rawValue
        let uiColor: UIColor
        switch type {
        case .shield: uiColor = UIColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0)
        case .boost:  uiColor = UIColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
        case .toxin:  uiColor = UIColor(red: 0.2, green: 1.0, blue: 0.3, alpha: 1.0)
        }
        let core = SCNBox(width: 0.65, height: 0.65, length: 0.65, chamferRadius: 0.28)
        core.materials = [makeMat(diffuse: uiColor.withAlphaComponent(0.25), emission: uiColor,
                                   emissionIntensity: 7.0, metalness: 0.95, roughness: 0.05)]
        root.addChildNode(SCNNode(geometry: core))
        let ring = SCNTorus(ringRadius: 0.7, pipeRadius: 0.045)
        ring.materials = [makeMat(diffuse: UIColor.clear, emission: uiColor,
                                   emissionIntensity: 6.0, metalness: 1.0, roughness: 0.0)]
        let rn = SCNNode(geometry: ring)
        rn.runAction(SCNAction.repeatForever(
            SCNAction.rotateBy(x: CGFloat.pi/2, y: CGFloat.pi*2, z: 0.4, duration: 2.0)
        ))
        root.addChildNode(rn)
        root.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi*2, z: 0, duration: 2.5)))
        let bobUp = SCNAction.moveBy(x: 0, y: 0.22, z: 0, duration: 0.7)
        let bobDn = SCNAction.moveBy(x: 0, y: -0.22, z: 0, duration: 0.7)
        bobUp.timingMode = .easeInEaseOut; bobDn.timingMode = .easeInEaseOut
        root.runAction(SCNAction.repeatForever(SCNAction.sequence([bobUp, bobDn])))
        return root
    }

    private func spawnPowerUps(centerZ: Float) {
        guard gameTime > 10, Int.random(in: 0...gameState.currentLevel.powerUpSpawnChance) == 0 else { return }
        let type = PowerUpType.allCases.randomElement()!
        let lane = Int.random(in: 0...2)
        let node = createPowerUpNode(type: type)
        node.position = SCNVector3(laneXPositions[lane], 1.3, centerZ + Float.random(in: -8...8))
        scene.rootNode.addChildNode(node); powerUpNodes.append(node)
    }

    private func activatePowerUpVisual(_ type: PowerUpType) {
        switch type {
        case .shield:
            shieldAuraNode?.removeFromParentNode()
            let s = SCNSphere(radius: 1.6); let m = SCNMaterial()
            m.diffuse.contents = UIColor.clear
            m.emission.contents = UIColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0)
            m.emission.intensity = 2.5; m.isDoubleSided = true; m.transparency = 0.65
            s.materials = [m]
            let sn = SCNNode(geometry: s); sn.opacity = 0.5
            sn.runAction(SCNAction.repeatForever(SCNAction.customAction(duration: 1.2) { n, e in
                n.opacity = CGFloat(0.3 + 0.2 * sin(Float(e / 1.2) * Float.pi))
            }))
            characterNode.addChildNode(sn); shieldAuraNode = sn
        case .boost:
            boostTrailNode?.removeFromParentNode()
            let tg = SCNBox(width: 0.15, height: 2.0, length: 3.0, chamferRadius: 0.05)
            let tm = SCNMaterial(); tm.diffuse.contents = UIColor.clear
            tm.emission.contents = UIColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0)
            tm.emission.intensity = 3.0; tg.materials = [tm]
            let tn = SCNNode(geometry: tg); tn.position = SCNVector3(0, 1.3, 1.5); tn.opacity = 0.6
            characterNode.addChildNode(tn); boostTrailNode = tn
        case .toxin:
            toxinAuraNode?.removeFromParentNode()
            let tg = SCNTorus(ringRadius: 1.0, pipeRadius: 0.07)
            let gm = SCNMaterial(); gm.diffuse.contents = UIColor.clear
            gm.emission.contents = UIColor(red: 0.2, green: 1.0, blue: 0.3, alpha: 1.0)
            gm.emission.intensity = 5.0; tg.materials = [gm]
            let gn = SCNNode(geometry: tg); gn.position = SCNVector3(0, 1.0, 0)
            gn.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0.3, y: CGFloat.pi*2, z: 0.2, duration: 1.5)))
            characterNode.addChildNode(gn); toxinAuraNode = gn
        }
    }

    private func clearPowerUpVisuals() {
        shieldAuraNode?.removeFromParentNode(); shieldAuraNode = nil
        boostTrailNode?.removeFromParentNode(); boostTrailNode = nil
        toxinAuraNode?.removeFromParentNode(); toxinAuraNode = nil
    }

    // MARK: - Road Management

    private func updateRoad() {
        let charZ = runnerNode.position.z
        while nextSegmentZ > charZ - lookaheadDistance {
            let seg = createSegment(atZ: nextSegmentZ)
            scene.rootNode.addChildNode(seg); segments.append(seg)
            if nextSegmentZ < -50 {
                spawnObstacles(centerZ: nextSegmentZ)
                spawnCoins(centerZ: nextSegmentZ)
                spawnPowerUps(centerZ: nextSegmentZ)
            }
            nextSegmentZ -= segmentLength
        }
        segments.removeAll { seg in
            guard seg.position.z > charZ + cleanupDistance else { return false }
            seg.removeFromParentNode(); return true
        }
        obstacles.removeAll { obs in
            guard obs.position.z > charZ + cleanupDistance else { return false }
            obs.removeFromParentNode()
            DispatchQueue.main.async { [weak self] in self?.gameState.incrementCombo() }
            return true
        }
        coins.removeAll { c in
            guard c.position.z > charZ + cleanupDistance else { return false }
            c.removeFromParentNode(); return true
        }
        powerUpNodes.removeAll { n in
            guard n.position.z > charZ + cleanupDistance else { return false }
            n.removeFromParentNode(); return true
        }
    }

    private func spawnObstacles(centerZ: Float) {
        let level = gameState.currentLevel
        guard Int.random(in: 0...level.obstacleSpawnChance) == 0 else { return }

        let maxCount = gameTime > 20 ? level.maxObstacleCount : min(level.maxObstacleCount, 1)
        let count = Int.random(in: 1...maxCount)
        let shuffled = [0, 1, 2].shuffled()
        for lane in shuffled.prefix(min(count, 2)) {
            let zOff = Float.random(in: -(segmentLength*0.3)...(segmentLength*0.3))
            let obs = createObstacle(lane: lane, atZ: centerZ + zOff)
            scene.rootNode.addChildNode(obs); obstacles.append(obs)
        }
    }

    // MARK: - Collision Detection (straight road — direct X comparison)

    private func checkCollisions() {
        // runnerNode.x is always 0; characterNode.x is the lane offset in world space
        let charX = characterNode.presentation.position.x
        let charZ = runnerNode.position.z

        for obs in obstacles {
            let dx = abs(charX - obs.position.x)   // both in world space (runnerNode.x == 0)
            let dz = abs(charZ - obs.position.z)
            if dx < hitThresholdX && dz < hitThresholdZ {
                handleCollision(with: obs); return
            }
            if dx < nearMissX && dz < nearMissZ && obs.name != "nearMissed" {
                obs.name = "nearMissed"
                DispatchQueue.main.async { [weak self] in self?.gameState.triggerNearMiss() }
            }
        }

        // Toxin: destroy same-lane obstacles ahead
        if gameState.hasToxin {
            for i in (0..<obstacles.count).reversed() {
                let obs = obstacles[i]
                let dx = abs(charX - obs.position.x)
                let dz = obs.position.z - charZ   // positive = ahead
                if dx < 1.2 && dz > -2 && dz < 20 {
                    destroyObstacle(obs); obstacles.remove(at: i)
                }
            }
        }

        // Coins
        coins.removeAll { coin in
            let dx = abs(charX - coin.position.x)
            let dz = abs(charZ - coin.position.z)

            if GameProgressStore.shared.hasMagnet, dx < coinPickupRadius, dz < 5.0 {
                coin.position.x += (charX - coin.position.x) * 0.18
                coin.position.z += (charZ - coin.position.z) * 0.05
            }

            guard dx < coinPickupRadius && dz < coinPickupRadius else { return false }
            coin.runAction(SCNAction.sequence([SCNAction.scale(to: 1.8, duration: 0.1),
                                               SCNAction.fadeOut(duration: 0.15)])) {
                coin.removeFromParentNode()
            }
            DispatchQueue.main.async { [weak self] in self?.gameState.collectCoin() }
            return true
        }

        // Power-ups
        powerUpNodes.removeAll { node in
            let dx = abs(charX - node.position.x)
            let dz = abs(charZ - node.position.z)
            guard dx < 1.2 && dz < 1.2 else { return false }
            if let typeName = node.name, let type = PowerUpType(rawValue: typeName) {
                node.removeFromParentNode()
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.gameState.activatePowerUp(type)
                    self.activatePowerUpVisual(type)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
            return true
        }

        // Clean auras when power-ups expire
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.gameState.hasShield { self.shieldAuraNode?.removeFromParentNode(); self.shieldAuraNode = nil }
            if !self.gameState.hasBoost  { self.boostTrailNode?.removeFromParentNode(); self.boostTrailNode = nil }
            if !self.gameState.hasToxin  { self.toxinAuraNode?.removeFromParentNode();  self.toxinAuraNode = nil }
        }
    }

    private func handleCollision(with obstacle: SCNNode) {
        guard isRunning, !isDead else { return }
        if gameState.hasShield {
            consumeObstacle(obstacle)
            DispatchQueue.main.async { [weak self] in
                self?.gameState.activePowerUps.removeValue(forKey: PowerUpType.shield.rawValue)
                self?.shieldAuraNode?.removeFromParentNode(); self?.shieldAuraNode = nil
            }
            UINotificationFeedbackGenerator().notificationOccurred(.warning); return
        }
        if GameProgressStore.shared.hasSaver && !saverUsed {
            saverUsed = true
            consumeObstacle(obstacle)
            DispatchQueue.main.async { [weak self] in
                self?.gameState.showSaverWarning = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.gameState.showSaverWarning = false }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.warning); return
        }
        isDead = true; isRunning = false
        DispatchQueue.main.async { [weak self] in self?.gameState.resetCombo() }
        [leftLegPivot, rightLegPivot, leftArmPivot, rightArmPivot, bodyContainer]
            .compactMap { $0 }.forEach { $0.removeAllActions() }
        let kb = SCNAction.group([SCNAction.moveBy(x: 0, y: 1.8, z: 2.0, duration: 0.14),
                                   SCNAction.rotateBy(x: CGFloat.pi * 0.8, y: 0, z: 0.5, duration: 0.14)])
        let fl = SCNAction.group([SCNAction.moveBy(x: 0, y: -2.8, z: 1.5, duration: 0.45),
                                   SCNAction.rotateBy(x: CGFloat.pi, y: 0, z: 0.4, duration: 0.45)])
        characterNode.runAction(SCNAction.sequence([kb, fl, SCNAction.fadeOut(duration: 0.25)]))
        SoundManager.shared.play(.crash); SoundManager.shared.stopAmbient(); clearPowerUpVisuals()
        DispatchQueue.main.async { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self] in
            self?.gameState.triggerGameOver()
        }
    }

    private func destroyObstacle(_ obs: SCNNode) {
        obs.runAction(SCNAction.sequence([SCNAction.scale(to: 1.6, duration: 0.08),
                                          SCNAction.fadeOut(duration: 0.25),
                                          SCNAction.removeFromParentNode()]))
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func consumeObstacle(_ obs: SCNNode) {
        destroyObstacle(obs)
        obstacles.removeAll { $0 === obs }
    }

    // MARK: - Game Loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard isRunning else { return }
        let delta = lastUpdateTime == 0 ? 0.016 : Float(time - lastUpdateTime)
        lastUpdateTime = time
        guard delta > 0, delta < 0.12 else { return }

        gameTime += delta
        let level = gameState.currentLevel
        let boostFactor: Float = gameState.hasBoost ? 1.5 : 1.0
        currentSpeed = min(
            (runBaseSpeed + gameTime * level.speedGrowthRate) * boostFactor,
            level.maxSpeed * boostFactor
        )

        let dist = currentSpeed * delta
        runnerNode.position.z -= dist
        totalDistance += dist

        let snap = totalDistance; let score = Int(snap / 8.0); let spd = currentSpeed
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.gameState.updateRunProgress(distance: snap, distanceScore: score, speed: spd)
            self.gameState.tickPowerUps(delta: delta)
            if score > 0, score % 50 == 0, score != self.lastHapticScore {
                self.lastHapticScore = score
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                SoundManager.shared.play(.milestone)
            }
        }
        updateRoad(); checkCollisions(); updateCamera()
    }

    // MARK: - Lane Switching

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isRunning, !isDead else { return }
        switch gesture.state {
        case .began:
            gestureStartX = gesture.location(in: gesture.view).x; gestureFired = false
        case .changed:
            guard !gestureFired else { return }
            let diff = gesture.location(in: gesture.view).x - gestureStartX
            if abs(diff) > 28 { gestureFired = true; switchLane(direction: diff > 0 ? 1 : -1) }
        default: break
        }
    }

    private func switchLane(direction: Int) {
        let newLane = max(0, min(2, currentLane + direction))
        guard newLane != currentLane else { return }
        currentLane = newLane
        let deltaX = CGFloat(laneXPositions[newLane] - characterNode.presentation.position.x)
        let move = SCNAction.moveBy(x: deltaX, y: 0, z: 0, duration: laneChangeDuration)
        move.timingMode = .easeInEaseOut
        characterNode.runAction(move, forKey: "laneSwitch")
        let tiltZ = CGFloat(-direction) * 0.27
        let tiltIn  = SCNAction.rotateTo(x: 0, y: 0, z: tiltZ, duration: laneChangeDuration * 0.5)
        let tiltOut = SCNAction.rotateTo(x: 0, y: 0, z: 0,     duration: laneChangeDuration * 0.5)
        bodyContainer.runAction(SCNAction.sequence([tiltIn, tiltOut]), forKey: "tilt")
        SoundManager.shared.play(.laneSwitch)
        DispatchQueue.main.async { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }

    // MARK: - Phase Management

    func handlePhaseChange(_ phase: GamePhase) {
        guard phase != currentPhase else { return }
        currentPhase = phase
        switch phase {
        case .playing: beginGame()
        case .menu:    stopAndReset()
        case .gameOver: break
        }
    }

    private func beginGame() {
        stopAndReset()
        applyThemeToScene()
        applySkills(); applySkin()
        isRunning = true; isDead = false
        lastUpdateTime = 0; gameTime = 0; totalDistance = 0
        lastHapticScore = 0; currentLane = 1; nextSegmentZ = 0
        SoundManager.shared.startAmbient()
    }

    private func stopAndReset() {
        isRunning = false
        [segments, obstacles, coins, powerUpNodes].forEach { $0.forEach { $0.removeFromParentNode() } }
        segments.removeAll(); obstacles.removeAll(); coins.removeAll(); powerUpNodes.removeAll()
        clearPowerUpVisuals()
        runnerNode.position = SCNVector3(0, 0, 0)   // always x=0 on straight road
        characterNode.removeAllActions()
        characterNode.position = SCNVector3(laneXPositions[1], 0, 0)
        characterNode.eulerAngles = SCNVector3(0, 0, 0)
        characterNode.opacity = 1.0
        bodyContainer.removeAllActions()
        bodyContainer.position = SCNVector3(0, 0, 0)
        bodyContainer.eulerAngles = SCNVector3(0, 0, 0)
        cameraNode.position = SCNVector3(0, 8, 14)
        cameraNode.constraints = []
        startRunningAnimations(); nextSegmentZ = 0
    }

    // MARK: - Material Helper

    private func makeMat(diffuse: UIColor, emission: UIColor, emissionIntensity: CGFloat,
                         metalness: CGFloat, roughness: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = diffuse; m.emission.contents = emission
        m.emission.intensity = emissionIntensity
        m.metalness.contents = metalness; m.roughness.contents = roughness
        return m
    }
}
