import SwiftUI
import SceneKit
import AVFoundation

private final class CatSceneView: SCNView {
    var updateFraming: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        updateFraming?()
    }
}

public struct Cat3DSceneView: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var speech = CatSpeechSynthesizer.shared
    @ObservedObject var actionHandler = CatActionHandler.shared
    var requestedMotion: CatMotion?
    var inRoom = false
    var isRoaming = false
    var lessonPaused = false
    var breathStep: BreathStep?
    var hideRequest = 0
    var recallRequest = 0
    var isVisible = true
    
    public init() {}

    init(motion: CatMotion?, inRoom: Bool = false, isRoaming: Bool = false,
         lessonPaused: Bool = false, breathStep: BreathStep? = nil, hideRequest: Int = 0, recallRequest: Int = 0, isVisible: Bool = true) {
        requestedMotion = motion
        self.inRoom = inRoom
        self.isRoaming = isRoaming
        self.lessonPaused = lessonPaused
        self.breathStep = breathStep
        self.hideRequest = hideRequest
        self.recallRequest = recallRequest
        self.isVisible = isVisible
    }
    
    public func makeUIView(context: Context) -> SCNView {
        let scnView = CatSceneView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        let backdrop = inRoom ? UIColor(red: 0.15, green: 0.14, blue: 0.13, alpha: 1) : .clear
        scnView.backgroundColor = backdrop
        scnView.isOpaque = inRoom
        scene.background.contents = backdrop
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 30
        scnView.isPlaying = true
        scnView.rendersContinuously = true
        
        let rootNode = scene.rootNode
        let evening = !(7..<21).contains(Calendar.current.component(.hour, from: Date()))
        
        // 1. СТУДИЙНОЕ КИНЕМАТОГРАФИЧЕСКОЕ ОСВЕЩЕНИЕ (4-точечный свет)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0)
        keyLight.light?.intensity = inRoom && evening ? 560 : 850
        keyLight.light?.castsShadow = inRoom
        keyLight.light?.shadowColor = UIColor(white: 0.12, alpha: 0.32)
        keyLight.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
        keyLight.light?.shadowRadius = 3
        keyLight.light?.orthographicScale = 3.4
        keyLight.position = SCNVector3(x: 2.2, y: 4.5, z: 4.2)
        keyLight.look(at: SCNVector3(0, 0.55, 0))
        rootNode.addChildNode(keyLight)
        
        let cyanRim = SCNNode()
        cyanRim.light = SCNLight()
        cyanRim.light?.type = .omni
        cyanRim.light?.color = UIColor(red: 0.65, green: 0.85, blue: 0.9, alpha: 1.0)
        cyanRim.light?.intensity = inRoom && evening ? 320 : 500
        cyanRim.position = SCNVector3(x: -3.0, y: 2.5, z: -2.8)
        rootNode.addChildNode(cyanRim)
        
        let magentaFill = SCNNode()
        magentaFill.light = SCNLight()
        magentaFill.light?.type = .omni
        magentaFill.light?.color = UIColor(red: 0.95, green: 0.8, blue: 0.68, alpha: 1.0)
        magentaFill.light?.intensity = 220
        magentaFill.position = SCNVector3(x: 2.8, y: -0.8, z: 2.2)
        rootNode.addChildNode(magentaFill)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(red: 0.22, green: 0.25, blue: 0.35, alpha: 1.0)
        rootNode.addChildNode(ambientLight)
        
        // Камера
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = inRoom ? SCNVector3(0, 2.20, 6.3) : SCNVector3(0, 1.05, 4)
        cameraNode.camera?.projectionDirection = .vertical
        cameraNode.camera?.fieldOfView = inRoom ? 46 : 38
        cameraNode.look(at: SCNVector3(0, 0.83, 0))
        scnView.pointOfView = cameraNode
        rootNode.addChildNode(cameraNode)
        
        if inRoom && !CatRoomScenery.install(in: scene) {
            DebugLogger.shared.log("Ошибка чтения ресурсов LivingRoom", level: .error, tag: "SceneKit")
        }
        
        if inRoom && (UserDefaults.standard.object(forKey: "aicat.lampOn") as? Bool) == false {
            CatRoomScenery.toggleLamp(in: scene)
        }

        // 3. ПЕРСОНАЖ: СТИЛЬНЫЙ КОТ AICAT
        let catRoot = SCNNode()
        catRoot.name = "AiCatRoot"
        catRoot.position = SCNVector3(0, 0, 0)
        
        if let rig = CatMotionRig(cat: catRoot) {
            context.coordinator.rig = rig
            Self.installOutfits(on: catRoot)
            let revision = Bundle.main.object(forInfoDictionaryKey: "AiCatSourceRevision") as? String ?? "локальная"
            DebugLogger.shared.log("BritishKitten v3 · Скелет подключён · Сборка \(revision)", tag: "SceneKit")
        } else {
            DebugLogger.shared.log("Ошибка чтения ресурсов CatModel", level: .error, tag: "SceneKit")
            let message = UILabel()
            message.text = "Не удалось загрузить 3D-модель BritishKitten из приложения."
            message.textColor = .white
            message.backgroundColor = UIColor.black.withAlphaComponent(0.7)
            message.numberOfLines = 0
            message.textAlignment = .center
            message.translatesAutoresizingMaskIntoConstraints = false
            scnView.addSubview(message)
            NSLayoutConstraint.activate([
                message.centerYAnchor.constraint(equalTo: scnView.centerYAnchor),
                message.leadingAnchor.constraint(equalTo: scnView.leadingAnchor),
                message.trailingAnchor.constraint(equalTo: scnView.trailingAnchor)
            ])
        }
        let traveller = SCNNode()
        traveller.eulerAngles.y = -0.54
        traveller.addChildNode(catRoot)
        let petSpace = SCNNode()
        let scale: Float = inRoom ? CatRoomScenery.kittenScale : 1
        petSpace.simdScale = SIMD3(repeating: scale)
        rootNode.addChildNode(petSpace)
        petSpace.addChildNode(traveller)
        context.coordinator.traveller = traveller
        if inRoom {
            let sphere = SCNSphere(radius: CGFloat(CatBallGame.radius))
            let yarn = SCNMaterial()
            yarn.diffuse.contents = UIColor(red: 0.82, green: 0.41, blue: 0.22, alpha: 1)
            sphere.firstMaterial = yarn
            let toy = SCNNode(geometry: sphere)
            let yarnBand = SCNMaterial()
            yarnBand.diffuse.contents = UIColor(red: 0.96, green: 0.76, blue: 0.46, alpha: 1)
            for angle: Float in [0.23, 0.36, 1.82] {
                let loop = SCNTorus(ringRadius: CGFloat(CatBallGame.radius), pipeRadius: 0.0025)
                loop.firstMaterial = yarnBand
                let stripe = SCNNode(geometry: loop)
                stripe.eulerAngles.z = angle
                toy.addChildNode(stripe)
            }
            toy.isHidden = true
            petSpace.addChildNode(toy)
            context.coordinator.toy = toy
            context.coordinator.view = scnView
            context.coordinator.bird = WindowBird(scene: scene)
            context.coordinator.visitors = RoomVisitors(scene: scene)
            scnView.updateFraming = { [weak coordinator = context.coordinator] in coordinator?.frameCamera(dt: nil) }
        }
        context.coordinator.startClock()
        
        // ЖЕСТЫ: Поглаживание (Pan) и Тап (Tap)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        tapGesture.require(toFail: doubleTap)
        scnView.addGestureRecognizer(doubleTap)
        scnView.addGestureRecognizer(tapGesture)
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        guard let cat = uiView.scene?.rootNode.childNode(withName: "AiCatRoot", recursively: true) else { return }
        
        let coordinator = context.coordinator
        coordinator.parent = self
        let animate = isVisible && scenePhase == .active && !reduceMotion && !lessonPaused
        uiView.isPlaying = animate
        uiView.rendersContinuously = animate
        coordinator.clock?.isPaused = !animate
        cat.isPaused = !animate
        let mood = actionHandler.state.moodEmoji
        let action = actionHandler.state.currentAction
        let motion: CatMotion = requestedMotion ?? (action == .wash || mood == "👅" ? .groom :
            action == .sleep || mood == "💤" ? .sleep :
            mood == "😻" ? .purr :
            mood == "🐟" ? .eat : mood == "💻" ? .computer :
            action == .play || mood == "🧶" ? .play : speech.isSpeaking ? .talk : .idle)
        // 1. Обновляем визуальный гардероб в 3D
        let outfit = actionHandler.state.isDressed ? actionHandler.state.currentOutfit : nil
        if coordinator.lastOutfit != outfit {
            updateOutfitVisibility(in: cat, currentOutfit: outfit, isDressed: outfit != nil)
            coordinator.lastOutfit = outfit
        }
        
        // 2. Выполняем конечно-автоматную анимацию под уникальным токеном
        let token = actionHandler.state.executionToken
        if context.coordinator.lastExecutedToken != token {
            context.coordinator.lastExecutedToken = token
            cat.removeAction(forKey: "cat_action")
            cat.simdPosition = .zero
            cat.simdEulerAngles = .zero
            cat.simdScale = [1, 1, 1]
            coordinator.resetGame()
            if requestedMotion == nil && !reduceMotion && (action == .somersault || action == .hangOnIsland || action == .dressUp) {
                executeCatAction(cat: cat, action: action)
            }
        }
        let poseChanged = coordinator.baseMotion != motion
        coordinator.baseMotion = motion
        if coordinator.lastHideRequest != hideRequest {
            coordinator.lastHideRequest = hideRequest
            coordinator.beginVisit(.hide)
        }
        if coordinator.lastRecallRequest != recallRequest {
            coordinator.lastRecallRequest = recallRequest
            coordinator.beginVisit(.recall)
        }
        if !animate {
            if !lessonPaused || poseChanged { coordinator.rig?.set(motion, reduced: true) }
            if reduceMotion { coordinator.showStillBall(playing: motion == .play) }
            uiView.setNeedsDisplay()
        }
    }
    
    // Переключение реальных 3D элементов одежды
    private func updateOutfitVisibility(in cat: SCNNode, currentOutfit: String?, isDressed: Bool) {
        let worn = isDressed ? CatGarment.matching(currentOutfit) : []
        for garment in CatGarment.allCases {
            cat.childNode(withName: garment.rawValue, recursively: true)?.isHidden = !worn.contains(garment)
        }
    }
    private static func installOutfits(on cat: SCNNode) {
        guard let head = cat.childNode(withName: "head", recursively: true),
              let neck = cat.childNode(withName: "neck", recursively: true) else { return }
        func item(_ name: String, on parent: SCNNode) -> SCNNode {
            let group = SCNNode()
            group.name = name
            group.isHidden = true
            parent.addChildNode(group)
            return group
        }
        func piece(_ mesh: SCNGeometry, color: UIColor, at position: SIMD3<Float>, in parent: SCNNode) -> SCNNode {
            let m = SCNMaterial()
            m.diffuse.contents = color
            mesh.firstMaterial = m
            let node = SCNNode(geometry: mesh)
            node.simdPosition = position
            parent.addChildNode(node)
            return node
        }
        func temple(side: Float, color: UIColor, in group: SCNNode) {
            let arm = piece(SCNBox(width: 0.019, height: 0.019, length: 0.40, chamferRadius: 0.006),
                            color: color, at: [side * 0.295, 0.087, 0.196], in: group)
            arm.eulerAngles.y = -side * 0.26
        }
        let glasses = item(CatGarment.glasses.rawValue, on: head)
        for side: Float in [-1, 1] {
            let rim = piece(SCNTorus(ringRadius: 0.099, pipeRadius: 0.014), color: .darkGray,
                            at: [side*0.15, 0.066, 0.390], in: glasses)
            rim.simdEulerAngles = [.pi/2 - 0.24, side * 0.12, -side*0.15]
            temple(side: side, color: .darkGray, in: glasses)
        }
        _ = piece(SCNBox(width: 0.11, height: 0.014, length: 0.016, chamferRadius: 0.005),
                  color: .darkGray, at: [0,0.067,0.402], in: glasses)
        let cap = item(CatGarment.cap.rawValue, on: head)
        let leather = UIColor(red: 0.26, green: 0.15, blue: 0.09, alpha: 1)
        let crown = piece(SCNSphere(radius: 0.20), color: leather, at: [0,0.319,0.035], in: cap)
        crown.simdScale = [1,0.40,1.04]
        let brim = piece(SCNSphere(radius: 0.17), color: leather, at: [0,0.30,0.19], in: cap)
        brim.simdScale = [1,0.09,0.84]
        let pendant = item(CatGarment.pendant.rawValue, on: neck)
        let band = piece(SCNTorus(ringRadius: 0.262, pipeRadius: 0.019), color: .brown,
                         at: [0,0.055,0.037], in: pendant)
        band.eulerAngles.x = -0.56
        let tag = piece(SCNSphere(radius: 0.038), color: .systemYellow, at: [0,-0.054,0.323], in: pendant)
        tag.simdScale = [1.24,1.24,0.42]
        let link = piece(SCNTorus(ringRadius: 0.022, pipeRadius: 0.006), color: .systemYellow,
                         at: [0,-0.015,0.313], in: pendant)
        link.eulerAngles.x = .pi/2
        let berry = UIColor(red: 0.54, green: 0.15, blue: 0.29, alpha: 1)
        let amber = UIColor(red: 0.87, green: 0.60, blue: 0.23, alpha: 1)
        let beret = item(CatGarment.beret.rawValue, on: head)
        let felt = piece(SCNSphere(radius: 1), color: berry, at: [-0.035,0.32,0.03], in: beret)
        felt.simdScale = [0.236,0.072,0.19]
        felt.eulerAngles.z = 0.16
        _ = piece(SCNCapsule(capRadius: 0.011, height: 0.042), color: berry, at: [-0.05,0.40,0.032], in: beret)
        let readers = item(CatGarment.readers.rawValue, on: head)
        for side: Float in [-1,1] {
            let rim = piece(SCNTorus(ringRadius: 0.093, pipeRadius: 0.007), color: amber,
                            at: [side*0.147,0.061,0.393], in: readers)
            rim.simdEulerAngles = [.pi/2 - 0.24, side * 0.12, -side*0.14]
            temple(side: side, color: amber, in: readers)
        }
        _ = piece(SCNBox(width: 0.116, height: 0.009, length: 0.012, chamferRadius: 0.004),
                  color: amber, at: [0,0.065,0.403], in: readers)
        let crown = item(CatGarment.crown.rawValue, on: head)
        let band = piece(SCNTorus(ringRadius: 0.16, pipeRadius: 0.019), color: .systemYellow, at: [0,0.31,0.05], in: crown)
        for i in 0..<7 {
            let angle = Float(i) * 2 * Float.pi / 7
            _ = piece(SCNCone(topRadius: 0.003, bottomRadius: 0.042, height: 0.095), color: .systemYellow,
                      at: [0.16*cos(angle),0.044,0.16*sin(angle)], in: band)
        }
        let necklace = item(CatGarment.pearl.rawValue, on: neck)
        for i in 0..<20 {
            let angle = Float(i) * 2 * Float.pi / 20
            _ = piece(SCNSphere(radius: 0.033), color: .white, at: [0.269*cos(angle),0.045-0.14*sin(angle),0.07+0.26*sin(angle)], in: necklace)
        }
        let bow = item(CatGarment.bow.rawValue, on: neck)
        let ribbon = piece(SCNTorus(ringRadius: 0.261, pipeRadius: 0.017), color: berry,
                           at: [0,0.049,0.042], in: bow)
        ribbon.eulerAngles.x = -0.56
        for side: Float in [-1,1] {
            let wing = piece(SCNCone(topRadius: 0.046, bottomRadius: 0.012, height: 0.076), color: berry,
                             at: [side*0.055,-0.044,0.365], in: bow)
            wing.eulerAngles.z = -side * .pi/2
        }
        _ = piece(SCNSphere(radius: 0.022), color: amber, at: [0,-0.044,0.377], in: bow)

    }

    private func scaleAction(from start: SCNVector3 = SCNVector3(1, 1, 1),
                             to end: SCNVector3, duration: TimeInterval) -> SCNAction {
        SCNAction.customAction(duration: duration) { node, elapsed in
            let progress = duration > 0 ? min(1, max(0, Float(elapsed) / Float(duration))) : 1
            node.scale = SCNVector3(
                start.x + (end.x - start.x) * progress,
                start.y + (end.y - start.y) * progress,
                start.z + (end.z - start.z) * progress
            )
        }
    }

    // Конечно-автоматное выполнение трюков с абсолютным возвратом в baseline
    private func executeCatAction(cat: SCNNode, action: CatActionType) {
        // Останавливаем предыдущую анимацию под ключом
        cat.removeAction(forKey: "cat_action")
        
        switch action {
        case .somersault:
            // 1. Приседание (Squash)
            let crouch = scaleAction(to: SCNVector3(1.15, 0.85, 1.15), duration: 0.12)
            // 2. Взрывной прыжок вверх (Leap)
            let leapUp = SCNAction.move(to: SCNVector3(0, 1.1, 0), duration: 0.35)
            leapUp.timingMode = .easeOut
            // 3. Сальто назад 360 градусов со стретчем
            let spin = SCNAction.rotateBy(x: -CGFloat(Double.pi * 2), y: 0, z: 0, duration: 0.55)
            let stretch = scaleAction(from: SCNVector3(1.15, 0.85, 1.15), to: SCNVector3(0.88, 1.18, 0.88), duration: 0.25)
            // 4. Приземление
            let fallDown = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.3)
            fallDown.timingMode = .easeIn
            // 5. Отскок и возврат в 100% базу
            let bounceLand = SCNAction.sequence([
                scaleAction(from: SCNVector3(0.88, 1.18, 0.88), to: SCNVector3(1.12, 0.9, 1.12), duration: 0.08),
                scaleAction(from: SCNVector3(1.12, 0.9, 1.12), to: SCNVector3(1.0, 1.0, 1.0), duration: 0.12),
                SCNAction.run { node in
                    node.eulerAngles = SCNVector3(0, 0, 0)
                    node.position = SCNVector3(0, 0, 0)
                }
            ])
            let jumpGroup = SCNAction.group([leapUp, spin, stretch])
            let fullSomersault = SCNAction.sequence([crouch, jumpGroup, fallDown, bounceLand])
            cat.runAction(fullSomersault, forKey: "cat_action")
            
        case .hangOnIsland:
            // Кот прыгает наверх прямо под Dynamic Island и раскачивается как маятник
            let jumpToIsland = SCNAction.move(to: SCNVector3(0, 1.3, 0.35), duration: 0.38)
            jumpToIsland.timingMode = .easeOut
            let swing = SCNAction.sequence([
                SCNAction.rotateTo(x: 0.12, y: 0, z: 0.15, duration: 0.45),
                SCNAction.rotateTo(x: -0.12, y: 0, z: -0.15, duration: 0.65),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.45)
            ])
            let landDown = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.32)
            landDown.timingMode = .easeIn
            
            cat.runAction(SCNAction.sequence([jumpToIsland, swing, landDown]), forKey: "cat_action")
            
        case .dressUp:
            // Модный поворот на 360 градусов при примерке одежды
            let twirl = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 0.7)
            cat.runAction(twirl, forKey: "cat_action")
            
        default: break
        }
    }

    public static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        view.rendersContinuously = false
        view.scene = nil
        coordinator.clock?.invalidate()
        CatPurrFeedback.shared.stop()
        coordinator.rig = nil
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    public class Coordinator: NSObject {
        var parent: Cat3DSceneView
        var rig: CatMotionRig?
        weak var traveller: SCNNode?
        weak var toy: SCNNode?
        weak var view: SCNView?
        private var game = CatBallGame()
        private var focusX: Float = 0
        private var fieldWidth: Float = 3.20
        var clock: CADisplayLink?
        var baseMotion: CatMotion = .idle {
            didSet {
                if baseMotion != oldValue {
                    endVisit()
                    holdingCat = false
                    destination = nil
                    resetGame()
                    rest = 2.5
                }
            }
        }
        private var destination: SIMD2<Float>?
        private var rest: Float = 2.5
        private var speed: Float = 0
        private var previousFrame: CFTimeInterval?
        private var holdingCat = false
        enum Visit { case mouse, scratch, sofa, window, hide, nudge, recall, descend }
        private var visit: Visit?
        private var nextVisit: (Visit, SIMD3<Float>?)?
        private var arrived = false
        private var targetWorld = SIMD3<Float>.zero
        private var jumpStart: SIMD3<Float>?
        private var visitTime: Float = 0
        private var autonomousTime: Float = 0
        var visitors: RoomVisitors?
        private var hideIndex = Int.random(in: 0..<4)
        private var mouseCountdown: Float = 35
        var bird: WindowBird?
        var lastOutfit: String?
        private var birdClock: Float = 0
        private var sign: SCNNode?
        private var effect: AVAudioPlayer?
        var lastExecutedToken: String = ""
        private var lastStroke: TimeInterval = 0
        private var lastPetTime: TimeInterval = 0
        
        var lastHideRequest: Int
        var lastRecallRequest: Int
        init(_ parent: Cat3DSceneView) {
            self.parent = parent
            lastHideRequest = parent.hideRequest
            lastRecallRequest = parent.recallRequest
        }

        func resetGame() {
            if game.phase != .idle { traveller?.simdPosition.y = 0 }
            game.stop()
            toy?.isHidden = true
        }

        func showStillBall(playing: Bool) {
            resetGame()
            guard playing, let traveller, let toy else { return }
            let p = traveller.simdConvertPosition([0.16,CatBallGame.radius,0.72], to: toy.parent)
            toy.simdPosition = p
            toy.isHidden = false
        }

        func frameCamera(dt: Float?) {
            guard let view, let cameraNode = view.pointOfView, let camera = cameraNode.camera,
                  let traveller, view.bounds.height > 0, view.bounds.width > 0 else { return }
            let position = traveller.simdWorldPosition
            let catX = position.x
            let ballX = game.ball.x * CatRoomScenery.kittenScale
            let playing = game.phase != .idle
            let following = 0.40 + 0.16 * min(1, max(0, position.z / 2))
            let desiredX = playing ? catX * 0.38 + ballX * 0.15 : catX * following
            let alpha = dt.map { 1 - exp(-3 * $0) } ?? 1
            focusX += (desiredX - focusX) * alpha
            let desiredWidth: Float = playing ? 6.90 : visit == .hide ? 5.50 : 3.20
            fieldWidth += (desiredWidth - fieldWidth) * alpha
            // Foreground subjects occupy more of the image at the same world-space width.
            let perspective = max(1, 5.5 / max(2, 6.30 - position.z))
            var half = max(fieldWidth / 2, (abs(catX - focusX) + 1.47 * CatRoomScenery.kittenScale) * perspective)
            if playing { half = max(half, (abs(ballX - focusX) + 0.22) * max(1, 5.5 / (6.3 - game.ball.y * CatRoomScenery.kittenScale))) }
            half = min(half, playing ? 6.7 : 2.85)
            let aspect = Float(view.bounds.width / view.bounds.height)
            camera.fieldOfView = CGFloat(2 * atan(max(1.48, half/aspect) / 5.5) * 180 / Float.pi)
            cameraNode.simdPosition = [focusX,2.20,6.30]
            cameraNode.look(at: SCNVector3(focusX,1.02,0))
        }

        func startClock() {
            let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
            link.preferredFramesPerSecond = 30
            link.add(to: .main, forMode: .common)
            clock = link
        }

        @objc private func frame(_ link: CADisplayLink) {
            let dt = Float(min(0.08, max(0, link.timestamp - (previousFrame ?? link.timestamp))))
            previousFrame = link.timestamp
            guard let rig, let traveller else { return }
            if parent.inRoom && !parent.reduceMotion {
                birdClock += dt
                if birdClock > 28 { birdClock = 0; bird?.fly(reducedMotion: false) }
            }
            if parent.inRoom && parent.requestedMotion == nil && baseMotion == .idle && !holdingCat && visit == nil && game.phase == .idle {
                mouseCountdown -= dt
                if mouseCountdown <= 0 {
                    mouseCountdown = Float.random(in: 55...90)
                    beginVisit(.mouse)
                }
                autonomousTime += dt
                if autonomousTime > 75 {
                    autonomousTime = 0
                    beginVisit(Bool.random() ? .window : .hide)
                }
            }
            if parent.requestedMotion != nil { endVisit() }
            if let visit {
                advanceVisit(visit, dt: dt, rig: rig, traveller: traveller)
                frameCamera(dt: dt)
                return
            }
            var motion = baseMotion
            var strideRate: Float = 1
            let position = SIMD2<Float>(traveller.simdPosition.x, traveller.simdPosition.z)
            if parent.inRoom && baseMotion == .play && game.phase == .idle && !holdingCat {
                game.start(at: position, facing: traveller.eulerAngles.y, repeats: true)
            }
            if game.phase != .idle, let toy {
                let before = game.ball
                if !holdingCat { game.advance(by: dt) }
                let delta = game.ball - before
                if simd_length_squared(delta) > 0.00000001 {
                    let axis = simd_normalize(SIMD3<Float>(delta.y,0,-delta.x))
                    toy.simdOrientation = simd_quatf(angle: simd_length(delta) / CatBallGame.radius, axis: axis) * toy.simdOrientation
                }
                toy.simdPosition = [game.ball.x,CatBallGame.radius,game.ball.y]
                toy.isHidden = game.phase == .idle
                traveller.simdPosition = [game.position.x,game.leapHeight,game.position.y]
                traveller.eulerAngles.y = game.heading
                switch game.phase {
                case .chasing: motion = game.strideRate * CatBallGame.runSpeed < 0.78 ? .walk : .trot
                case .batting: motion = .play
                case .rollingAway, .idle: motion = .idle
                }
                strideRate = motion == .walk ? game.strideRate * CatBallGame.runSpeed / 0.58 : game.strideRate * CatBallGame.runSpeed / 1.38
                if game.leapPhase != nil { motion = .pounce }
                if game.phase == .batting {
                    traveller.simdPosition.y = max(0, sin(min(1, game.battingProgress) * .pi)) * 0.10
                }
            } else if parent.inRoom && parent.requestedMotion == nil && baseMotion != .sleep && !holdingCat {
                rest -= dt
                if destination == nil && rest <= 0 && parent.isRoaming &&
                    [.idle, .groom, .play, .computer].contains(baseMotion) {
                    let x: Float = traveller.simdPosition.x > 0 ? -0.64 : 0.64
                    destination = [x, Float.random(in: -0.44...0.16)]
                }
                if let target = destination {
                    let offset = target - position
                    let distance = simd_length(offset)
                    if distance < 0.025 {
                        destination = nil
                        toy?.isHidden = true
                        rest = Float.random(in: 7...16)
                    } else {
                        motion = .walk
                        let direction = offset / distance
                        let heading = atan2(direction.x, direction.y)
                        turn(traveller, to: heading, step: dt)
                        let alignment = max(0, cos(heading - traveller.eulerAngles.y))
                        let desiredSpeed = min(distance > 0.85 ? CatBallGame.runSpeed : 0.58, sqrt(2 * 1.6 * distance)) * alignment
                        speed += max(-2.4 * dt, min(1.6 * dt, desiredSpeed - speed))
                        let step = min(distance, dt * speed)
                        motion = speed > 0.75 ? .trot : .walk
                        strideRate = dt > 0 ? step / (dt * (motion == .trot ? 1.38 : 0.58)) : 0
                        let next = position + direction * step
                        traveller.simdPosition = [next.x, 0, next.y]
                    }
                }
            }
            if motion != .walk && motion != .trot && game.phase == .idle {
                speed = 0
                if motion != .sleep {
                    let sideView = motion == .computer || motion == .eat || motion.isExercise
                    turn(traveller, to: sideView ? -1.10 : -0.54, step: dt)
                }
            }
            if parent.requestedMotion == .walk { turn(traveller, to: -1.10, step: dt) }
            if holdingCat { motion = .purr }
            rig.set(motion, reduced: false)
            rig.advance(by: dt, strideRate: strideRate, breathPhase: parent.breathStep?.phase(at: Date()), leapPhase: game.leapPhase)
            frameCamera(dt: dt)
        }

        private func turn(_ node: SCNNode, to angle: Float, step: Float) {
            let delta = angle - node.eulerAngles.y
            node.eulerAngles.y += atan2(sin(delta), cos(delta)) * min(1, step * 6)
        }

        private func hitsCat(_ point: CGPoint, in view: SCNView) -> Bool {
            var node = view.hitTest(point, options: nil).first?.node
            while let hit = node {
                if hit.name == "AiCatRoot" { return true }
                node = hit.parent
            }
            return false
        }

        func beginVisit(_ kind: Visit, at point: SIMD3<Float>? = nil) {
            guard parent.inRoom, parent.requestedMotion == nil, baseMotion != .sleep || kind == .recall, let traveller else { return }
            if !parent.reduceMotion, traveller.simdWorldPosition.y > 0.10,
               visit == .sofa || visit == .window || visit == .hide || visit == .descend {
                nextVisit = (kind, point)
                if visit != .descend { descend() }
                return
            }
            endVisit()
            resetGame()
            destination = nil
            speed = 0
            autonomousTime = 0
            holdingCat = false
            visit = kind
            switch kind {
            case .descend: return
            case .recall: targetWorld = .zero
            case .hide:
                let places: [SIMD3<Float>] = [[-1.12,0.31,-2.92],[-2.64,0,-2.12],[1.11,0,-2.76],[2.29,0,-2.88]]
                hideIndex = (hideIndex + 1) % places.count
                targetWorld = places[hideIndex]
            case .mouse:
                if parent.reduceMotion { endVisit(); return }
                visitors?.start()
            case .window:
                targetWorld = CatRoomScenery.sofaSeat(tappedX: -1.5)
                if bird == nil, let scene = view?.scene { bird = WindowBird(scene: scene) }
                bird?.fly(reducedMotion: parent.reduceMotion)
            case .sofa:
                targetWorld = CatRoomScenery.sofaSeat(tappedX: point?.x ?? 0)
            case .scratch: targetWorld = CatRoomScenery.floorTarget(point ?? traveller.simdWorldPosition)
            case .nudge:
                jumpStart = traveller.simdPosition
                let position = traveller.simdWorldPosition
                let side: Float = (point?.x ?? position.x) >= position.x ? -1 : 1
                targetWorld = CatRoomScenery.floorTarget([position.x + side * 0.18, 0, position.z])
                feedback("Nudge")
            }
            if parent.reduceMotion {
                traveller.simdPosition = targetWorld / CatRoomScenery.kittenScale
                arrived = true
                if kind == .hide { showSearchSign() }
                else if kind == .scratch { feedback("Scratch"); endVisit() }
                else if kind == .nudge || kind == .recall { endVisit() }
                else {
                    traveller.eulerAngles.y = targetWorld.x < -1 ? 1.45 : -1.45
                    rig?.set(.think, reduced: true)
                }
            }
        }

        private func endVisit() {
            guard visit != nil else { return }
            visitors?.mouse.isHidden = true
            let leavingFurniture = visit == .sofa || visit == .window || visit == .hide || visit == .descend
            visit = nil
            nextVisit = nil
            rig?.gaze = .zero
            visitTime = 0
            arrived = false
            jumpStart = nil
            sign?.removeFromParentNode()
            sign = nil
            effect?.stop()
            if let traveller, traveller.position.y > 0 {
                traveller.simdPosition.y = 0
                if leavingFurniture { traveller.simdPosition.z = -1.35 / CatRoomScenery.kittenScale }
            }
            rest = 4
        }

        private func feedback(_ sound: String) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            guard CatSpeechSynthesizer.shared.isVoiceEnabled, !OfflineSpeechRecognizer.shared.isRecording,
                  let url = Bundle.main.url(forResource: sound, withExtension: "wav", subdirectory: "CatModel") else { return }
            effect = try? AVAudioPlayer(contentsOf: url)
            effect?.play()
        }

        private func advanceVisit(_ kind: Visit, dt: Float, rig: CatMotionRig, traveller: SCNNode) {
            let scale = CatRoomScenery.kittenScale
            if kind == .mouse {
                guard let mouse = visitors?.advance(dt, chasedBy: traveller.simdWorldPosition) else { endVisit(); return }
                let target = CatRoomScenery.floorTarget(mouse) / scale
                let delta = target - traveller.simdPosition
                let distance = simd_length(delta)
                let yaw = atan2(delta.x,delta.z)
                turn(traveller, to: yaw, step: dt * 1.5)
                let step = min(max(0, distance-0.42), dt * 3.15 * max(0,cos(yaw-traveller.eulerAngles.y)))
                if distance > 0.001 { traveller.simdPosition += delta * (step/distance) }
                rig.set(step > dt * 0.7 ? .trot : .play, reduced: false)
                rig.advance(by: dt, strideRate: step / max(0.001,dt*1.38))
                return
            }
            let goal = targetWorld / scale
            let high = targetWorld.y > 0.1
            let seatHeading: Float = targetWorld.x < -1 ? 1.45 : -1.45
            let approach = high ? SIMD3<Float>(goal.x, 0, -1.45 / scale) : goal
            let offset = approach - traveller.simdPosition
            let distance = simd_length(offset)
            var pose = CatMotion.idle
            var rate: Float = 1
            if kind == .nudge, let start = jumpStart {
                visitTime += dt
                let t = min(1, visitTime / 0.32)
                traveller.simdPosition = start + (goal - start) * (1 - (1-t)*(1-t)) + SIMD3(0, 0.17*t*(1-t), 0)
                pose = .walk
                rate = 1.6
                if t >= 1 { endVisit() }
            } else if kind == .descend, let start = jumpStart {
                visitTime += dt
                let t = min(1, visitTime / 0.55)
                traveller.simdPosition = start + (goal - start) * t + SIMD3(0, 0.95 * t * (1-t), 0)
                pose = .stretch
                if t >= 1 {
                    let requested = nextVisit
                    traveller.simdPosition = goal
                    endVisit()
                    if let (kind, point) = requested { beginVisit(kind, at: point) }
                }
            } else if !arrived && jumpStart == nil && distance > 0.035 {
                let yaw = atan2(offset.x, offset.z)
                turn(traveller, to: yaw, step: dt)
                let alignment = max(0.15, cos(yaw - traveller.eulerAngles.y))
                let desired = min(high || distance > 1.3 ? 1.65 : 0.68, sqrt(4 * distance)) * alignment
                speed += min(2.6 * dt, max(-3 * dt, desired - speed))
                traveller.simdPosition += offset / distance * min(distance, speed * dt)
                pose = speed > 0.78 ? .trot : .walk
                rate = speed / (pose == .walk ? 0.58 : 1.38)
            } else if high && !arrived {
                let start = jumpStart ?? traveller.simdPosition
                jumpStart = start
                visitTime += dt
                let t = min(1, visitTime / 0.47)
                traveller.simdPosition = start + (goal - start) * t + SIMD3(0, 1.3 * t * (1-t), 0)
                if kind == .sofa || kind == .window { turn(traveller, to: seatHeading, step: dt * 2) }
                pose = t > 0.70 ? .think : .stretch
                if t >= 1 { arrived = true; visitTime = 0 }
            } else {
                if !arrived { arrived = true; speed = 0 }
                visitTime += dt
                switch kind {
                case .mouse, .descend: break
                case .recall: endVisit()
                case .scratch:
                    pose = .scratch
                    if Int(visitTime / 0.52) != Int((visitTime - dt) / 0.52) { feedback("Scratch") }
                    if visitTime > 2.6 { endVisit() }
                case .nudge: break
                case .hide:
                    pose = .think
                    turn(traveller, to: -0.4, step: dt)
                    if sign == nil { showSearchSign() }
                case .window, .sofa:
                    pose = .think
                    turn(traveller, to: seatHeading, step: dt)
                    if kind == .window, let position = bird?.visiblePosition {
                        let local = traveller.simdConvertPosition(position, from: nil)
                        rig.gaze = [min(1,max(-1,local.x)), -min(1,max(0,local.y*0.45))]
                    }
                    if visitTime > 16 { descend() }
                }
            }
            rig.set(pose, reduced: false)
            rig.advance(by: dt, strideRate: rate)
        }

        private func descend() {
            if parent.reduceMotion || (traveller?.simdWorldPosition.y ?? 0) < 0.05 { endVisit(); return }
            guard let traveller else { return }
            sign?.removeFromParentNode()
            sign = nil
            jumpStart = traveller.simdPosition
            targetWorld = [traveller.simdWorldPosition.x, 0, -1.36]
            visit = .descend
            visitTime = 0
            arrived = false
        }

        private func showSearchSign() {
            let text = SCNText(string: "Найди кота", extrusionDepth: 0.03)
            text.font = UIFont.systemFont(ofSize: 10, weight: .bold)
            text.firstMaterial?.diffuse.contents = UIColor.white
            text.firstMaterial?.lightingModel = .constant
            let label = SCNNode(geometry: text)
            let bounds = label.boundingBox
            label.pivot = SCNMatrix4MakeTranslation((bounds.min.x + bounds.max.x)/2, 0, 0)
            label.simdScale = SIMD3(repeating: 1.42 / max(1, bounds.max.x-bounds.min.x))
            guard let visitors else { return }
            label.simdPosition = visitors.captionAnchor
            let backing = SCNPlane(width: 1.5, height: 0.45)
            backing.firstMaterial?.diffuse.contents = UIColor.black
            let plate = SCNNode(geometry: backing)
            plate.simdPosition = label.simdPosition + SIMD3(0,0.13,-0.015)
            let group = SCNNode()
            group.addChildNode(plate)
            group.addChildNode(label)
            view?.scene?.rootNode.addChildNode(group)
            sign = group
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.inRoom, parent.requestedMotion == nil, let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            guard let hit = view.hitTest(point, options: nil).first else { return }
            let p = hit.worldCoordinates
            if hitsCat(point, in: view) {
                if visit == .hide { descend(); feedback("Nudge") }
                else { beginVisit(.nudge, at: [p.x, p.y, p.z]) }
            } else if hit.node.name == "SittingRoom", abs(p.y) < 0.035,
                      CatRoomScenery.rugX.contains(p.x), CatRoomScenery.rugZ.contains(p.z) {
                beginVisit(.scratch, at: [p.x,0,p.z])
            }
        }

        private func moveToy(to point: CGPoint, in view: SCNView) {
            guard !parent.reduceMotion, parent.requestedMotion == nil, baseMotion != .sleep else { return }
            let near = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
            let far = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
            let dy = far.y - near.y
            guard dy < -0.001 else { return }
            let t = -near.y / dy
            guard (0...1).contains(t) else { return }
            let target = SIMD2(near.x + (far.x - near.x) * t, near.z + (far.z - near.z) * t)
            guard CatRoomScenery.rugX.contains(target.x), CatRoomScenery.rugZ.contains(target.y), let traveller else { return }
            endVisit()
            destination = nil
            if game.phase == .idle {
                game.start(at: SIMD2(traveller.simdPosition.x, traveller.simdPosition.z),
                           facing: traveller.eulerAngles.y, target: target / CatRoomScenery.kittenScale,
                           repeats: baseMotion == .play)
            } else { game.throwBall(towards: target / CatRoomScenery.kittenScale) }
        }
        
        // ПОГЛАЖИВАНИЕ СВАЙПОМ: плавное мурчание и тактильный отклик
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard visit == nil, parent.inRoom, parent.requestedMotion == nil, let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            if gesture.state == .began {
                // UIKit recognises a pan after movement. Hit-test the initial contact.
                let translation = gesture.translation(in: view)
                holdingCat = hitsCat(CGPoint(x: point.x - translation.x, y: point.y - translation.y), in: view)
                if holdingCat { resetGame() }
            }
            guard holdingCat else {
                if gesture.state == .began || gesture.state == .changed { moveToy(to: point, in: view) }
                return
            }
            rig?.gaze = [Float(point.x / max(view.bounds.width, 1) * 2 - 1),
                         Float(point.y / max(view.bounds.height, 1) * 2 - 1)]
            if gesture.state == .cancelled || gesture.state == .failed {
                holdingCat = false
                rig?.gaze = .zero
                CatPurrFeedback.shared.stop()
                return
            }
            let now = Date().timeIntervalSince1970
            if gesture.state == .began || (gesture.state == .changed && now - lastStroke > 0.12) {
                lastStroke = now
                CatPurrFeedback.shared.respond(for: 0.48)
            }
            
            if gesture.state == .ended {
                holdingCat = false
                rig?.gaze = .zero
                if now - lastPetTime > 1 {
                    lastPetTime = now
                    _ = TamagotchiManager.shared.petCat()
                }
            }
        }
        
        // ТАП: быстрое почесывание за ушком
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.inRoom, parent.requestedMotion == nil, let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            if visit == .hide && arrived {
                // Accept a tap on the silhouette even when a basket or cushion covers the frontmost mesh.
                let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
                if hits.contains(where: { $0.node.name == "BritishKittenSkin" }) {
                    descend()
                    feedback("Nudge")
                }
                return
            }
            if view.hitTest(point, options: nil).first?.node.name == "MouseDoor" {
                beginVisit(.mouse)
                return
            }
            if let node = view.hitTest(point, options: nil).first?.node, bird?.owns(node) == true {
                if visit == .window { bird?.fly(reducedMotion: parent.reduceMotion) }
                else { beginVisit(.window) }
                return
            }
            if !hitsCat(point, in: view) {
                if let hit = view.hitTest(point, options: nil).first, hit.node.name == "SittingRoom" {
                    let p = hit.worldCoordinates
                    let local = SIMD3<Float>(p.x, p.y, p.z + 2.75) / 1.23 - SIMD3(0,0,2.75)
                    if (-1.89...0.77).contains(local.x), (1.10...2.90).contains(local.y), local.z < -2.70 {
                        if visit == .window { bird?.fly(reducedMotion: parent.reduceMotion) }
                        else { beginVisit(.window) }
                        return
                    }
                    if abs(local.x - 1.44) < 0.38 && abs(local.z + 2.35) < 0.50 && local.y > 0.04 {
                        if let on = CatRoomScenery.toggleLamp(in: view.scene) {
                            UserDefaults.standard.set(on, forKey: "aicat.lampOn")
                        }
                        return
                    }
                    if (-2.12...0.51).contains(local.x), (-2.94 ... -1.91).contains(local.z), local.y > 0.08 {
                        if visit != .hide { beginVisit(.sofa, at: [p.x,p.y,p.z]) }
                        return
                    }
                }
                guard visit != .hide else { return }
                moveToy(to: point, in: view)
                return
            }
            let now = Date().timeIntervalSince1970
            if visit == .hide { descend(); feedback("Nudge"); return }
            guard now - lastPetTime > 1 else { return }
            lastPetTime = now
            _ = TamagotchiManager.shared.petCat()
        }
    }
}
