import SwiftUI
import SceneKit

public struct Cat3DSceneView: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var speech = CatSpeechSynthesizer.shared
    @ObservedObject var actionHandler = CatActionHandler.shared
    var requestedMotion: CatMotion?
    var inRoom = false
    var isRoaming = false
    var isVisible = true
    
    public init() {}

    init(motion: CatMotion?, inRoom: Bool = false, isRoaming: Bool = false, isVisible: Bool = true) {
        requestedMotion = motion
        self.inRoom = inRoom
        self.isRoaming = isRoaming
        self.isVisible = isVisible
    }
    
    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.clear
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 30
        scnView.isPlaying = true
        scnView.rendersContinuously = true
        
        let rootNode = scene.rootNode
        
        // 1. СТУДИЙНОЕ КИНЕМАТОГРАФИЧЕСКОЕ ОСВЕЩЕНИЕ (4-точечный свет)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0)
        keyLight.light?.intensity = 850
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
        cyanRim.light?.intensity = 500
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
        cameraNode.position = inRoom ? SCNVector3(0, 1.88, 4.25) : SCNVector3(0, 1.05, 4)
        cameraNode.camera?.fieldOfView = inRoom ? 46 : 38
        cameraNode.look(at: SCNVector3(0, 1.0, 0))
        scnView.pointOfView = cameraNode
        rootNode.addChildNode(cameraNode)
        
        if inRoom { CatRoomScenery.install(in: scene) }
        
        // 3. ПЕРСОНАЖ: СТИЛЬНЫЙ КОТ AICAT
        let catRoot = SCNNode()
        catRoot.name = "AiCatRoot"
        catRoot.position = SCNVector3(0, 0, 0)
        
        // Отдельный узел для дыхания (чтобы сальто и трюки не конфликтовали с дыханием!)
        let breatheNode = SCNNode()
        breatheNode.name = "BreatheNode"
        catRoot.addChildNode(breatheNode)
        
        // Материалы кота
        let furMaterial = SCNMaterial()
        furMaterial.diffuse.contents = Self.furTexture // Сапфирово-серый британец
        furMaterial.roughness.contents = 0.95
        furMaterial.lightingModel = .physicallyBased
        furMaterial.specular.contents = UIColor(white: 0.35, alpha: 1.0)
        
        let furWhiteMaterial = SCNMaterial()
        furWhiteMaterial.diffuse.contents = UIColor(red: 0.66, green: 0.68, blue: 0.71, alpha: 1.0)
        furWhiteMaterial.roughness.contents = 0.6
        
        let pinkMaterial = SCNMaterial()
        pinkMaterial.diffuse.contents = UIColor(red: 0.75, green: 0.43, blue: 0.48, alpha: 1.0)
        
        let eyeMaterial = SCNMaterial()
        eyeMaterial.diffuse.contents = UIColor(red: 0.42, green: 0.78, blue: 0.20, alpha: 1.0) // Изумрудный свет
        eyeMaterial.specular.contents = UIColor(white: 0.8, alpha: 1)
        eyeMaterial.shininess = 0.8
        
        // --- ГОЛОВА ---
        let headGeo = SCNSphere(radius: 0.52)
        headGeo.firstMaterial = furMaterial
        let headNode = SCNNode(geometry: headGeo)
        headNode.name = "Head"
        headNode.position = SCNVector3(0, 1.25, 0)
        headNode.simdScale = [1.04, 0.94, 1]
        breatheNode.addChildNode(headNode)
        let stripe = SCNMaterial()
        stripe.diffuse.contents = UIColor(red: 0.23, green: 0.25, blue: 0.28, alpha: 1)
        // Short silver-tabby bars follow the curvature of the forehead.
        for index in -1...1 {
            let mark = SCNNode(geometry: SCNSphere(radius: 1))
            mark.geometry?.firstMaterial = stripe
            mark.simdScale = [0.024, 0.088, 0.012]
            let x = Float(index) * 0.095
            let y: Float = 0.29
            mark.simdPosition = [x, y, sqrt(0.52 * 0.52 - x * x - y * y)]
            mark.simdEulerAngles = [-0.60, x * 2, -x]
            headNode.addChildNode(mark)
        }
        
        // Щечки
        let cheekGeo = SCNSphere(radius: 0.105)
        cheekGeo.firstMaterial = furWhiteMaterial
        let leftCheek = SCNNode(geometry: cheekGeo)
        leftCheek.position = SCNVector3(-0.09, -0.13, 0.47)
        headNode.addChildNode(leftCheek)
        
        let rightCheek = SCNNode(geometry: cheekGeo)
        rightCheek.position = SCNVector3(0.09, -0.13, 0.47)
        headNode.addChildNode(rightCheek)
        
        // Носик
        let noseGeo = SCNSphere(radius: 0.045)
        noseGeo.firstMaterial = pinkMaterial
        let noseNode = SCNNode(geometry: noseGeo)
        noseNode.position = SCNVector3(0, -0.075, 0.55)
        headNode.addChildNode(noseNode)
        
        // Глаза с морганием
        let eyeGeo = SCNSphere(radius: 0.145)
        eyeGeo.firstMaterial = eyeMaterial
        let leftEye = SCNNode(geometry: eyeGeo)
        leftEye.position = SCNVector3(-0.205, 0.065, 0.445)
        leftEye.name = "LeftEye"
        headNode.addChildNode(leftEye)
        
        let rightEye = SCNNode(geometry: eyeGeo)
        rightEye.position = SCNVector3(0.205, 0.065, 0.445)
        rightEye.name = "RightEye"
        headNode.addChildNode(rightEye)
        
        let blinkAction = SCNAction.sequence([
            SCNAction.wait(duration: 3.5),
            scaleAction(to: SCNVector3(1.0, 0.1, 1.0), duration: 0.08),
            scaleAction(from: SCNVector3(1.0, 0.1, 1.0), to: SCNVector3(1.0, 1.0, 1.0), duration: 0.08)
        ])
        leftEye.runAction(SCNAction.repeatForever(blinkAction), forKey: "blink")
        rightEye.runAction(SCNAction.repeatForever(blinkAction), forKey: "blink")

        for eye in [leftEye, rightEye] {
            let pupil = SCNNode(geometry: SCNSphere(radius: 0.072))
            pupil.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.025, alpha: 1)
            pupil.scale = SCNVector3(0.55, 1.2, 0.28)
            pupil.position = SCNVector3(0, 0, 0.13)
            eye.addChildNode(pupil)
            let glint = SCNNode(geometry: SCNSphere(radius: 0.028))
            glint.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            glint.geometry?.firstMaterial?.lightingModel = .constant
            glint.position = SCNVector3(-0.035, 0.045, 0.14)
            eye.addChildNode(glint)
        }

        let mouth = SCNNode(geometry: SCNSphere(radius: 0.036))
        mouth.name = "Mouth"
        mouth.position = SCNVector3(0, -0.195, 0.515)
        mouth.scale = SCNVector3(0.7, 0.18, 0.3)
        mouth.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.08, alpha: 1)
        headNode.addChildNode(mouth)
        
        // Усы
        let whiskerGeo = SCNCylinder(radius: 0.006, height: 0.42)
        whiskerGeo.firstMaterial?.diffuse.contents = UIColor.white
        for (i, angle) in [-0.15, 0.0, 0.15].enumerated() {
            let yOff = Float(i) * 0.035
            let lw = SCNNode(geometry: whiskerGeo)
            lw.position = SCNVector3(-0.35, -0.13 + yOff, 0.38)
            lw.eulerAngles = SCNVector3(0, 0, Float.pi / 2.0 + Float(angle))
            headNode.addChildNode(lw)
            
            let rw = SCNNode(geometry: whiskerGeo)
            rw.position = SCNVector3(0.35, -0.13 + yOff, 0.38)
            rw.eulerAngles = SCNVector3(0, 0, Float.pi / 2.0 - Float(angle))
            headNode.addChildNode(rw)
        }
        
        // Ушки
        let earGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.19, height: 0.36)
        earGeo.firstMaterial = furMaterial
        let leftEar = SCNNode(geometry: earGeo)
        leftEar.name = "LeftEar"
        leftEar.position = SCNVector3(-0.32, 0.49, 0.05)
        leftEar.eulerAngles = SCNVector3(0, 0, 0.28)
        leftEar.simdScale.z = 0.62
        headNode.addChildNode(leftEar)
        
        let rightEar = SCNNode(geometry: earGeo)
        rightEar.name = "RightEar"
        rightEar.position = SCNVector3(0.32, 0.49, 0.05)
        rightEar.eulerAngles = SCNVector3(0, 0, -0.28)
        rightEar.simdScale.z = 0.62
        headNode.addChildNode(rightEar)
        
        let innerEarGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.11, height: 0.26)
        innerEarGeo.firstMaterial = pinkMaterial
        let leftInner = SCNNode(geometry: innerEarGeo)
        leftInner.position = SCNVector3(0, -0.01, 0.085)
        leftEar.addChildNode(leftInner)
        
        let rightInner = SCNNode(geometry: innerEarGeo)
        rightInner.position = leftInner.position
        rightEar.addChildNode(rightInner)
        
        let earTwitch = SCNAction.sequence([
            SCNAction.wait(duration: 4.5),
            SCNAction.rotateBy(x: 0, y: 0, z: -0.18, duration: 0.08),
            SCNAction.rotateBy(x: 0, y: 0, z: 0.18, duration: 0.08)
        ])
        leftEar.runAction(SCNAction.repeatForever(earTwitch))
        
        // --- ГАРДЕРОБ 1: ЧЕРНЫЕ КИБЕР-ОЧКИ ---
        let outfitGlasses = SCNNode()
        outfitGlasses.name = "Outfit_Glasses"
        let glassesGeo = SCNBox(width: 0.76, height: 0.22, length: 0.14, chamferRadius: 0.04)
        glassesGeo.firstMaterial?.diffuse.contents = UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.95)
        glassesGeo.firstMaterial?.metalness.contents = 0.9
        let glassesBase = SCNNode(geometry: glassesGeo)
        glassesBase.position = SCNVector3(0, 0.07, 0.49)
        outfitGlasses.addChildNode(glassesBase)
        
        let neonStripGeo = SCNBox(width: 0.72, height: 0.025, length: 0.15, chamferRadius: 0.01)
        neonStripGeo.firstMaterial?.diffuse.contents = UIColor.systemCyan
        neonStripGeo.firstMaterial?.emission.contents = UIColor.systemCyan
        let neonNode = SCNNode(geometry: neonStripGeo)
        neonNode.position = SCNVector3(0, 0.12, 0.50)
        outfitGlasses.addChildNode(neonNode)
        headNode.addChildNode(outfitGlasses)
        
        // --- ГАРДЕРОБ 2: КОЖАНАЯ КЕПКА ---
        let outfitCap = SCNNode()
        outfitCap.name = "Outfit_Cap"
        let capDomeGeo = SCNSphere(radius: 0.38)
        capDomeGeo.firstMaterial?.diffuse.contents = UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1.0)
        let capDome = SCNNode(geometry: capDomeGeo)
        capDome.position = SCNVector3(0, 0.44, 0.02)
        capDome.scale = SCNVector3(1.1, 0.5, 1.1)
        outfitCap.addChildNode(capDome)
        
        let capVisorGeo = SCNBox(width: 0.52, height: 0.03, length: 0.32, chamferRadius: 0.01)
        capVisorGeo.firstMaterial?.diffuse.contents = UIColor(red: 0.16, green: 0.10, blue: 0.08, alpha: 1.0)
        let capVisor = SCNNode(geometry: capVisorGeo)
        capVisor.position = SCNVector3(0, 0.36, 0.38)
        capVisor.eulerAngles = SCNVector3(0.25, 0, 0)
        outfitCap.addChildNode(capVisor)
        outfitCap.isHidden = true
        headNode.addChildNode(outfitCap)
        
        // --- ТЕЛО И ОШЕЙНИК ---
        let bodyGeo = SCNCapsule(capRadius: 0.44, height: 0.98)
        bodyGeo.firstMaterial = furMaterial
        let bodyNode = SCNNode(geometry: bodyGeo)
        bodyNode.name = "Body"
        bodyNode.position = SCNVector3(0, 0.52, -0.05)
        breatheNode.addChildNode(bodyNode)
        
        let bibGeo = SCNSphere(radius: 0.32)
        bibGeo.firstMaterial = furWhiteMaterial
        let bibNode = SCNNode(geometry: bibGeo)
        bibNode.name = "Bib"
        bibNode.position = SCNVector3(0, 0.62, 0.22)
        bibNode.scale = SCNVector3(0.8, 1.1, 0.5)
        breatheNode.addChildNode(bibNode)
        
        let collarGeo = SCNCylinder(radius: 0.36, height: 0.04)
        collarGeo.firstMaterial?.diffuse.contents = UIColor.systemRed
        let collarNode = SCNNode(geometry: collarGeo)
        collarNode.name = "Collar"
        collarNode.position = SCNVector3(0, 0.88, 0.02)
        breatheNode.addChildNode(collarNode)
        
        let bellGeo = SCNSphere(radius: 0.06)
        bellGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        bellGeo.firstMaterial?.metalness.contents = 0.95
        let bellNode = SCNNode(geometry: bellGeo)
        bellNode.name = "Bell"
        bellNode.position = SCNVector3(0, 0.84, 0.38)
        breatheNode.addChildNode(bellNode)
        
        // --- ГАРДЕРОБ 3: НЕОНОВЫЙ ХУДИ ---
        let outfitHoodie = SCNNode()
        outfitHoodie.name = "Outfit_Hoodie"
        let hoodieGeo = SCNCapsule(capRadius: 0.46, height: 1.02)
        hoodieGeo.firstMaterial?.diffuse.contents = UIColor(red: 0.05, green: 0.15, blue: 0.25, alpha: 1.0)
        let hoodieBody = SCNNode(geometry: hoodieGeo)
        hoodieBody.position = SCNVector3(0, 0.52, -0.05)
        outfitHoodie.addChildNode(hoodieBody)
        
        let hoodieTrimGeo = SCNTorus(ringRadius: 0.38, pipeRadius: 0.03)
        hoodieTrimGeo.firstMaterial?.diffuse.contents = UIColor.systemCyan
        hoodieTrimGeo.firstMaterial?.emission.contents = UIColor.systemCyan
        let hoodieTrim = SCNNode(geometry: hoodieTrimGeo)
        hoodieTrim.position = SCNVector3(0, 0.92, 0.02)
        outfitHoodie.addChildNode(hoodieTrim)
        outfitHoodie.isHidden = true
        breatheNode.addChildNode(outfitHoodie)
        
        // --- ГАРДЕРОБ 4: ЗОЛОТОЙ КУЛОН-ЛАПКА ---
        let outfitPendant = SCNNode()
        outfitPendant.name = "Outfit_Pendant"
        let chainGeo = SCNTorus(ringRadius: 0.38, pipeRadius: 0.015)
        chainGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        chainGeo.firstMaterial?.metalness.contents = 0.95
        let chainNode = SCNNode(geometry: chainGeo)
        chainNode.position = SCNVector3(0, 0.86, 0.02)
        outfitPendant.addChildNode(chainNode)
        
        let medalGeo = SCNCylinder(radius: 0.10, height: 0.02)
        medalGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        medalGeo.firstMaterial?.metalness.contents = 0.95
        let medalNode = SCNNode(geometry: medalGeo)
        medalNode.position = SCNVector3(0, 0.72, 0.38)
        medalNode.eulerAngles = SCNVector3(Float.pi / 2.0, 0, 0)
        outfitPendant.addChildNode(medalNode)
        outfitPendant.isHidden = true
        breatheNode.addChildNode(outfitPendant)
        
        // ЛАПКИ
        let tailRoot = SCNNode()
        tailRoot.name = "TailRoot"
        tailRoot.position = SCNVector3(0, 0.28, -0.42)
        
        let curve: [SIMD3<Float>] = [[0,0,0], [0.19,-0.10,-0.17], [0.42,-0.13,-0.22],
                                     [0.57,-0.03,-0.16], [0.64,0.16,-0.09], [0.61,0.30,0]]
        for i in 1..<curve.count {
            let delta = curve[i] - curve[i - 1]
            let radius = 0.087 - Float(i) * 0.005
            let segment = SCNNode(geometry: SCNCapsule(capRadius: CGFloat(radius),
                                                     height: CGFloat(simd_length(delta) + 2 * radius)))
            segment.geometry?.firstMaterial = i == curve.count - 1 ? stripe : furMaterial
            segment.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))
            segment.simdPosition = (curve[i] + curve[i - 1]) * 0.5
            tailRoot.addChildNode(segment)
        }
        breatheNode.addChildNode(tailRoot)
        
        let traveller = SCNNode()
        traveller.addChildNode(catRoot)
        rootNode.addChildNode(traveller)
        context.coordinator.traveller = traveller
        if inRoom {
            let toy = SCNNode(geometry: SCNSphere(radius: 0.072))
            toy.geometry?.firstMaterial?.diffuse.contents = UIColor.systemOrange
            toy.isHidden = true
            rootNode.addChildNode(toy)
            context.coordinator.toy = toy
        }
        context.coordinator.rig = CatMotionRig(cat: catRoot, torso: breatheNode, head: headNode,
                                               tail: tailRoot, fur: furMaterial)
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
        let animate = isVisible && scenePhase == .active && !reduceMotion
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
        let asleep = motion == .sleep
        if coordinator.wasAsleep != asleep || coordinator.reduced != reduceMotion {
            context.coordinator.wasAsleep = asleep
            coordinator.reduced = reduceMotion
            for name in ["LeftEye", "RightEye"] {
                guard let eye = cat.childNode(withName: name, recursively: true) else { continue }
                eye.removeAction(forKey: "blink")
                eye.scale = SCNVector3(1, asleep ? 0.08 : 1, 1)
                if !asleep && !reduceMotion {
                    let blink = SCNAction.sequence([
                        .wait(duration: mood == "😻" ? 1.5 : 3.5),
                        scaleAction(to: SCNVector3(1, 0.1, 1), duration: 0.08),
                        scaleAction(from: SCNVector3(1, 0.1, 1), to: SCNVector3(1, 1, 1), duration: 0.12)
                    ])
                    eye.runAction(.repeatForever(blink), forKey: "blink")
                }
            }
        }
        if let mouth = cat.childNode(withName: "Mouth", recursively: true) {
            let movesMouth = !reduceMotion && !asleep && (speech.isSpeaking || motion == .eat || motion == .groom)
            if movesMouth && mouth.action(forKey: "talk") == nil {
                mouth.runAction(.repeatForever(.sequence([
                    scaleAction(from: SCNVector3(0.7, 0.18, 0.3), to: SCNVector3(0.7, 0.8, 0.3), duration: 0.14),
                    scaleAction(from: SCNVector3(0.7, 0.8, 0.3), to: SCNVector3(0.7, 0.18, 0.3), duration: 0.16)
                ])), forKey: "talk")
            } else if !movesMouth {
                mouth.removeAction(forKey: "talk")
                mouth.scale = SCNVector3(0.7, 0.18, 0.3)
            }
        }

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
            if requestedMotion == nil && !reduceMotion && (action == .somersault || action == .hangOnIsland || action == .dressUp) {
                executeCatAction(cat: cat, action: action)
            }
        }
        coordinator.baseMotion = motion
        if !animate {
            coordinator.rig?.set(motion, reduced: true)
            uiView.setNeedsDisplay()
        }
    }
    
    // Переключение реальных 3D элементов одежды
    private func updateOutfitVisibility(in cat: SCNNode, currentOutfit: String?, isDressed: Bool) {
        let glasses = cat.childNode(withName: "Outfit_Glasses", recursively: true)
        let hoodie = cat.childNode(withName: "Outfit_Hoodie", recursively: true)
        let cap = cat.childNode(withName: "Outfit_Cap", recursively: true)
        let pendant = cat.childNode(withName: "Outfit_Pendant", recursively: true)
        let collar = cat.childNode(withName: "Collar", recursively: true)
        let bell = cat.childNode(withName: "Bell", recursively: true)
        
        guard isDressed, let outfit = currentOutfit else {
            // Естественная шубка: всё снято
            glasses?.isHidden = true
            hoodie?.isHidden = true
            cap?.isHidden = true
            pendant?.isHidden = true
            collar?.isHidden = false
            bell?.isHidden = false
            return
        }
        
        glasses?.isHidden = !outfit.contains("очки")
        hoodie?.isHidden = !outfit.contains("худи")
        cap?.isHidden = !outfit.contains("кепка")
        pendant?.isHidden = !outfit.contains("кулон")
        
        // Под худи ошейник прячется
        collar?.isHidden = outfit.contains("худи")
        bell?.isHidden = outfit.contains("худи")
    }
    
    private static let furTexture: UIImage = {
        let size = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.39, green: 0.42, blue: 0.46, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.setLineWidth(0.6)
            var seed: UInt32 = 107
            func coordinate() -> CGFloat {
                seed = seed &* 1664525 &+ 1013904223
                return CGFloat(seed >> 16) / 128
            }
            for index in 0..<6000 {
                let x = coordinate()
                let y = coordinate()
                let light = CGFloat(index % 7) / 30 + 0.3
                cg.setStrokeColor(UIColor(white: light, alpha: 0.5).cgColor)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addLine(to: CGPoint(x: x + CGFloat(index % 5) - 2, y: y + 7))
                cg.strokePath()
            }
        }
    }()

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
        coordinator.rig = nil
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    public class Coordinator: NSObject {
        var parent: Cat3DSceneView
        var wasAsleep: Bool?
        var reduced = false
        var rig: CatMotionRig?
        weak var traveller: SCNNode?
        weak var toy: SCNNode?
        var clock: CADisplayLink?
        var baseMotion: CatMotion = .idle {
            didSet {
                if baseMotion != oldValue {
                    destination = nil
                    toy?.isHidden = true
                    rest = 2.5
                }
            }
        }
        private var destination: SIMD2<Float>?
        private var rest: Float = 2.5
        private var previousFrame: CFTimeInterval?
        private var holdingCat = false
        var lastExecutedToken: String = ""
        private var lastHapticTime: TimeInterval = 0
        private var lastPetTime: TimeInterval = 0
        
        init(_ parent: Cat3DSceneView) { self.parent = parent }

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
            if parent.inRoom && parent.requestedMotion == nil && baseMotion != .sleep && !holdingCat {
                rest -= dt
                if destination == nil && rest <= 0 && parent.isRoaming &&
                    [.idle, .groom, .play, .computer].contains(baseMotion) {
                    let x: Float = traveller.simdPosition.x > 0 ? -0.64 : 0.64
                    destination = [x, Float.random(in: -0.44...0.16)]
                }
                if let target = destination {
                    let position = SIMD2<Float>(traveller.simdPosition.x, traveller.simdPosition.z)
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
                        let next = position + direction * min(distance, dt * 0.58 * alignment)
                        traveller.simdPosition = [next.x, 0, next.y]
                    }
                }
            }
            if motion != .walk { turn(traveller, to: 0, step: dt) }
            rig.set(motion, reduced: false)
            rig.advance(by: dt)
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
            let x = min(0.70, max(-0.70, near.x + (far.x - near.x) * t))
            let z = min(0.22, max(-0.50, near.z + (far.z - near.z) * t))
            destination = [x, z]
            toy?.simdPosition = [x, 0.075, z]
            toy?.isHidden = false
        }
        
        // ПОГЛАЖИВАНИЕ СВАЙПОМ: плавное мурчание и тактильный отклик
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.inRoom, let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            if gesture.state == .began {
                // UIKit recognises a pan after movement. Hit-test the initial contact.
                let translation = gesture.translation(in: view)
                holdingCat = hitsCat(CGPoint(x: point.x - translation.x, y: point.y - translation.y), in: view)
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
                return
            }
            let now = Date().timeIntervalSince1970
            if now - lastHapticTime > 0.12 {
                lastHapticTime = now
                let softHaptic = UIImpactFeedbackGenerator(style: .soft)
                softHaptic.impactOccurred(intensity: 0.7)
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
            guard parent.inRoom, let view = gesture.view as? SCNView else { return }
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
