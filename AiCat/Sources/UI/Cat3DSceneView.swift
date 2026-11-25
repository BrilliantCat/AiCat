import SwiftUI
import SceneKit

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
    var isVisible = true
    
    public init() {}

    init(motion: CatMotion?, inRoom: Bool = false, isRoaming: Bool = false,
         lessonPaused: Bool = false, breathStep: BreathStep? = nil, isVisible: Bool = true) {
        requestedMotion = motion
        self.inRoom = inRoom
        self.isRoaming = isRoaming
        self.lessonPaused = lessonPaused
        self.breathStep = breathStep
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
            scnView.updateFraming = { [weak coordinator = context.coordinator] in coordinator?.frameCamera(dt: nil) }
        }
        context.coordinator.startClock()
        
        // ЖЕСТЫ: Поглаживание (Pan) и Тап (Tap)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
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
        updateOutfitVisibility(in: cat, currentOutfit: actionHandler.state.currentOutfit, isDressed: actionHandler.state.isDressed)
        
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
              let neck = cat.childNode(withName: "neck", recursively: true),
              let chest = cat.childNode(withName: "chest", recursively: true) else { return }
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
        let glasses = item(CatGarment.glasses.rawValue, on: head)
        for side: Float in [-1, 1] {
            let rim = piece(SCNTorus(ringRadius: 0.099, pipeRadius: 0.009), color: .darkGray,
                            at: [side*0.15, 0.067, 0.295], in: glasses)
            rim.simdEulerAngles = [.pi/2, 0, -side*0.24]
        }
        _ = piece(SCNBox(width: 0.11, height: 0.014, length: 0.016, chamferRadius: 0.005),
                  color: .darkGray, at: [0,0.067,0.31], in: glasses)
        let cap = item(CatGarment.cap.rawValue, on: head)
        let leather = UIColor(red: 0.26, green: 0.15, blue: 0.09, alpha: 1)
        let crown = piece(SCNSphere(radius: 0.20), color: leather, at: [0,0.26,0], in: cap)
        crown.simdScale = [1,0.40,1.04]
        let brim = piece(SCNSphere(radius: 0.17), color: leather, at: [0,0.235,0.14], in: cap)
        brim.simdScale = [1,0.09,0.84]
        let hoodie = item(CatGarment.hoodie.rawValue, on: chest)
        let hood = piece(SCNTorus(ringRadius: 0.21, pipeRadius: 0.045), color: .systemTeal,
                         at: [0,0.14,0.17], in: hoodie)
        hood.eulerAngles.x = -0.53
        let garment = piece(SCNSphere(radius: 1), color: .systemTeal, at: [0,-0.013,-0.01], in: hoodie)
        garment.simdScale = [0.28,0.315,0.31]
        let pendant = item(CatGarment.pendant.rawValue, on: neck)
        let band = piece(SCNTorus(ringRadius: 0.224, pipeRadius: 0.012), color: .brown,
                         at: [0,0.055,0.037], in: pendant)
        band.eulerAngles.x = -0.56
        let tag = piece(SCNSphere(radius: 0.038), color: .systemYellow, at: [0,-0.035,0.256], in: pendant)
        tag.simdScale.z = 0.36
        let berry = UIColor(red: 0.54, green: 0.15, blue: 0.29, alpha: 1)
        let amber = UIColor(red: 0.87, green: 0.60, blue: 0.23, alpha: 1)
        let beret = item(CatGarment.beret.rawValue, on: head)
        let felt = piece(SCNSphere(radius: 1), color: berry, at: [-0.035,0.28,0.03], in: beret)
        felt.simdScale = [0.236,0.072,0.19]
        felt.eulerAngles.z = 0.16
        _ = piece(SCNCapsule(capRadius: 0.011, height: 0.042), color: berry, at: [-0.05,0.355,0.032], in: beret)
        let readers = item(CatGarment.readers.rawValue, on: head)
        for side: Float in [-1,1] {
            let rim = piece(SCNTorus(ringRadius: 0.093, pipeRadius: 0.007), color: amber,
                            at: [side*0.147,0.060,0.30], in: readers)
            rim.simdEulerAngles = [.pi/2,0,-side*0.27]
        }
        _ = piece(SCNBox(width: 0.116, height: 0.009, length: 0.012, chamferRadius: 0.004),
                  color: amber, at: [0,0.065,0.316], in: readers)
        let bow = item(CatGarment.bow.rawValue, on: neck)
        let ribbon = piece(SCNTorus(ringRadius: 0.223, pipeRadius: 0.014), color: berry,
                           at: [0,0.049,0.042], in: bow)
        ribbon.eulerAngles.x = -0.56
        for side: Float in [-1,1] {
            let wing = piece(SCNCone(topRadius: 0.046, bottomRadius: 0.012, height: 0.076), color: berry,
                             at: [side*0.043,-0.041,0.254], in: bow)
            wing.eulerAngles.z = -side * .pi/2
        }
        _ = piece(SCNSphere(radius: 0.022), color: amber, at: [0,-0.041,0.264], in: bow)
        let vest = item(CatGarment.vest.rawValue, on: chest)
        let wool = piece(SCNSphere(radius: 1), color: amber, at: [0,-0.022,-0.054], in: vest)
        wool.simdScale = [0.29,0.309,0.36]
        for offset: Float in [0.00,-0.077] {
            _ = piece(SCNSphere(radius: 0.016), color: .brown, at: [0,offset,0.304], in: vest)
        }
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
        var lastExecutedToken: String = ""
        private var lastStroke: TimeInterval = 0
        private var lastPetTime: TimeInterval = 0
        
        init(_ parent: Cat3DSceneView) { self.parent = parent }

        func resetGame() {
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
            let catX = traveller.simdWorldPosition.x
            let ballX = game.ball.x * CatRoomScenery.kittenScale
            let playing = game.phase != .idle
            let desiredX = playing ? catX * 0.38 + ballX * 0.15 : catX * 0.4
            let alpha = dt.map { 1 - exp(-3 * $0) } ?? 1
            focusX += (desiredX - focusX) * alpha
            let desiredWidth: Float = playing ? 4.20 : 3.20
            fieldWidth += (desiredWidth - fieldWidth) * alpha
            var half = max(fieldWidth / 2, abs(catX - focusX) + 1.47 * CatRoomScenery.kittenScale)
            if playing { half = max(half, abs(ballX - focusX) + 0.22) }
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
                traveller.simdPosition = [game.position.x,0,game.position.y]
                traveller.eulerAngles.y = game.heading
                switch game.phase {
                case .chasing: motion = .trot
                case .batting: motion = .play
                case .rollingAway, .idle: motion = .idle
                }
                strideRate = game.strideRate
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
                        let desiredSpeed = min(0.58, sqrt(2 * 1.6 * distance)) * alignment
                        speed += max(-2.4 * dt, min(1.6 * dt, desiredSpeed - speed))
                        let step = min(distance, dt * speed)
                        strideRate = dt > 0 ? step / (dt * 0.58) : 0
                        let next = position + direction * step
                        traveller.simdPosition = [next.x, 0, next.y]
                    }
                }
            }
            if motion != .walk && game.phase == .idle {
                speed = 0
                if motion != .sleep {
                    let sideView = motion == .computer || motion == .eat || motion.isExercise
                    turn(traveller, to: sideView ? -1.10 : -0.54, step: dt)
                }
            }
            if parent.requestedMotion == .walk { turn(traveller, to: -1.10, step: dt) }
            if holdingCat { motion = .purr }
            rig.set(motion, reduced: false)
            rig.advance(by: dt, strideRate: strideRate, breathPhase: parent.breathStep?.phase(at: Date()))
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

        private func moveToy(to point: CGPoint, in view: SCNView) {
            guard !parent.reduceMotion, parent.requestedMotion == nil, baseMotion != .sleep else { return }
            let near = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
            let far = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
            let dy = far.y - near.y
            guard dy < -0.001 else { return }
            let t = -near.y / dy
            guard (0...1).contains(t) else { return }
            let target = SIMD2(near.x + (far.x - near.x) * t, near.z + (far.z - near.z) * t)
            guard abs(target.x) <= 2.55, (-1.47...1.57).contains(target.y), let traveller else { return }
            destination = nil
            if game.phase == .idle {
                game.start(at: SIMD2(traveller.simdPosition.x, traveller.simdPosition.z),
                           facing: traveller.eulerAngles.y, target: target / CatRoomScenery.kittenScale,
                           repeats: baseMotion == .play)
            } else { game.throwBall(towards: target / CatRoomScenery.kittenScale) }
        }
        
        // ПОГЛАЖИВАНИЕ СВАЙПОМ: плавное мурчание и тактильный отклик
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.inRoom, parent.requestedMotion == nil, let view = gesture.view as? SCNView else { return }
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
            if !hitsCat(point, in: view) {
                moveToy(to: point, in: view)
                return
            }
            let now = Date().timeIntervalSince1970
            guard now - lastPetTime > 1 else { return }
            lastPetTime = now
            _ = TamagotchiManager.shared.petCat()
        }
    }
}
