import SwiftUI
import SceneKit

public struct Cat3DSceneView: UIViewRepresentable {
    @ObservedObject var actionHandler = CatActionHandler.shared
    
    public init() {}
    
    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.clear
        scnView.antialiasingMode = .multisampling4X
        
        let rootNode = scene.rootNode
        
        // 1. СТУДИЙНОЕ КИНЕМАТОГРАФИЧЕСКОЕ ОСВЕЩЕНИЕ (4-точечный свет)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor(red: 1.0, green: 0.98, blue: 0.94, alpha: 1.0)
        keyLight.light?.intensity = 1500
        keyLight.position = SCNVector3(x: 2.2, y: 4.5, z: 4.2)
        keyLight.eulerAngles = SCNVector3(-0.5, 0.45, 0)
        rootNode.addChildNode(keyLight)
        
        let cyanRim = SCNNode()
        cyanRim.light = SCNLight()
        cyanRim.light?.type = .omni
        cyanRim.light?.color = UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 1.0)
        cyanRim.light?.intensity = 1250
        cyanRim.position = SCNVector3(x: -3.0, y: 2.5, z: -2.8)
        rootNode.addChildNode(cyanRim)
        
        let magentaFill = SCNNode()
        magentaFill.light = SCNLight()
        magentaFill.light?.type = .omni
        magentaFill.light?.color = UIColor(red: 0.85, green: 0.25, blue: 0.95, alpha: 1.0)
        magentaFill.light?.intensity = 700
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
        cameraNode.position = SCNVector3(x: 0, y: 0.98, z: 3.0)
        rootNode.addChildNode(cameraNode)
        
        // 2. КИБЕР-ПЬЕДЕСТАЛ С ВРАЩАЮЩИМИСЯ НЕОНОВЫМИ КОЛЬЦАМИ
        let pedestalRoot = SCNNode()
        let discGeo = SCNCylinder(radius: 1.1, height: 0.04)
        discGeo.firstMaterial?.diffuse.contents = UIColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 1.0)
        discGeo.firstMaterial?.metalness.contents = 0.8
        let discNode = SCNNode(geometry: discGeo)
        discNode.position = SCNVector3(0, -0.02, 0)
        pedestalRoot.addChildNode(discNode)
        
        let ringGeo = SCNTorus(ringRadius: 0.95, pipeRadius: 0.022)
        ringGeo.firstMaterial?.diffuse.contents = UIColor.systemCyan
        ringGeo.firstMaterial?.emission.contents = UIColor.systemCyan
        let ringNode = SCNNode(geometry: ringGeo)
        ringNode.position = SCNVector3(0, 0.015, 0)
        let ringRotate = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 9.0)
        ringNode.runAction(SCNAction.repeatForever(ringRotate))
        pedestalRoot.addChildNode(ringNode)
        rootNode.addChildNode(pedestalRoot)
        
        // 3. ПЕРСОНАЖ: СТИЛЬНЫЙ КОТ AICAT
        let catRoot = SCNNode()
        catRoot.name = "AiCatRoot"
        catRoot.position = SCNVector3(0, 0, 0)
        
        // Отдельный узел для дыхания (чтобы сальто и трюки не конфликтовали с дыханием!)
        let breatheNode = SCNNode()
        breatheNode.name = "BreatheNode"
        let breatheAction = SCNAction.sequence([
            scaleAction(to: SCNVector3(1.025, 1.03, 1.025), duration: 1.6),
            scaleAction(from: SCNVector3(1.025, 1.03, 1.025), to: SCNVector3(1.0, 1.0, 1.0), duration: 1.6)
        ])
        breatheNode.runAction(SCNAction.repeatForever(breatheAction), forKey: "breathe_idle")
        catRoot.addChildNode(breatheNode)
        
        // Материалы кота
        let furMaterial = SCNMaterial()
        furMaterial.diffuse.contents = UIColor(red: 0.22, green: 0.25, blue: 0.33, alpha: 1.0) // Сапфирово-серый британец
        furMaterial.roughness.contents = 0.52
        furMaterial.specular.contents = UIColor(white: 0.35, alpha: 1.0)
        
        let furWhiteMaterial = SCNMaterial()
        furWhiteMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
        furWhiteMaterial.roughness.contents = 0.6
        
        let pinkMaterial = SCNMaterial()
        pinkMaterial.diffuse.contents = UIColor(red: 0.98, green: 0.62, blue: 0.72, alpha: 1.0)
        
        let eyeMaterial = SCNMaterial()
        eyeMaterial.diffuse.contents = UIColor(red: 0.1, green: 0.95, blue: 0.5, alpha: 1.0) // Изумрудный свет
        eyeMaterial.emission.contents = UIColor(red: 0.05, green: 0.4, blue: 0.18, alpha: 1.0)
        
        // --- ГОЛОВА ---
        let headGeo = SCNSphere(radius: 0.52)
        headGeo.firstMaterial = furMaterial
        let headNode = SCNNode(geometry: headGeo)
        headNode.name = "Head"
        headNode.position = SCNVector3(0, 1.25, 0)
        breatheNode.addChildNode(headNode)
        
        // Щечки
        let cheekGeo = SCNSphere(radius: 0.16)
        cheekGeo.firstMaterial = furWhiteMaterial
        let leftCheek = SCNNode(geometry: cheekGeo)
        leftCheek.position = SCNVector3(-0.13, -0.13, 0.40)
        headNode.addChildNode(leftCheek)
        
        let rightCheek = SCNNode(geometry: cheekGeo)
        rightCheek.position = SCNVector3(0.13, -0.13, 0.40)
        headNode.addChildNode(rightCheek)
        
        // Носик
        let noseGeo = SCNSphere(radius: 0.065)
        noseGeo.firstMaterial = pinkMaterial
        let noseNode = SCNNode(geometry: noseGeo)
        noseNode.position = SCNVector3(0, -0.07, 0.49)
        headNode.addChildNode(noseNode)
        
        // Глаза с морганием
        let eyeGeo = SCNSphere(radius: 0.11)
        eyeGeo.firstMaterial = eyeMaterial
        let leftEye = SCNNode(geometry: eyeGeo)
        leftEye.position = SCNVector3(-0.20, 0.07, 0.40)
        headNode.addChildNode(leftEye)
        
        let rightEye = SCNNode(geometry: eyeGeo)
        rightEye.position = SCNVector3(0.20, 0.07, 0.40)
        headNode.addChildNode(rightEye)
        
        let blinkAction = SCNAction.sequence([
            SCNAction.wait(duration: 3.5),
            scaleAction(to: SCNVector3(1.0, 0.1, 1.0), duration: 0.08),
            scaleAction(from: SCNVector3(1.0, 0.1, 1.0), to: SCNVector3(1.0, 1.0, 1.0), duration: 0.08)
        ])
        leftEye.runAction(SCNAction.repeatForever(blinkAction))
        rightEye.runAction(SCNAction.repeatForever(blinkAction))
        
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
        headNode.addChildNode(leftEar)
        
        let rightEar = SCNNode(geometry: earGeo)
        rightEar.name = "RightEar"
        rightEar.position = SCNVector3(0.32, 0.49, 0.05)
        rightEar.eulerAngles = SCNVector3(0, 0, -0.28)
        headNode.addChildNode(rightEar)
        
        let innerEarGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.11, height: 0.26)
        innerEarGeo.firstMaterial = pinkMaterial
        let leftInner = SCNNode(geometry: innerEarGeo)
        leftInner.position = SCNVector3(-0.30, 0.47, 0.12)
        leftInner.eulerAngles = SCNVector3(-0.12, 0, 0.28)
        headNode.addChildNode(leftInner)
        
        let rightInner = SCNNode(geometry: innerEarGeo)
        rightInner.position = SCNVector3(0.30, 0.47, 0.12)
        rightInner.eulerAngles = SCNVector3(-0.12, 0, -0.28)
        headNode.addChildNode(rightInner)
        
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
        let pawGeo = SCNCapsule(capRadius: 0.10, height: 0.38)
        pawGeo.firstMaterial = furWhiteMaterial
        let leftPaw = SCNNode(geometry: pawGeo)
        leftPaw.name = "LeftPaw"
        leftPaw.position = SCNVector3(-0.22, 0.22, 0.28)
        breatheNode.addChildNode(leftPaw)
        
        let rightPaw = SCNNode(geometry: pawGeo)
        rightPaw.name = "RightPaw"
        rightPaw.position = SCNVector3(0.22, 0.22, 0.28)
        breatheNode.addChildNode(rightPaw)
        
        let hindGeo = SCNSphere(radius: 0.24)
        hindGeo.firstMaterial = furMaterial
        let leftHind = SCNNode(geometry: hindGeo)
        leftHind.position = SCNVector3(-0.36, 0.24, -0.05)
        leftHind.scale = SCNVector3(0.8, 0.9, 1.2)
        breatheNode.addChildNode(leftHind)
        
        let rightHind = SCNNode(geometry: hindGeo)
        rightHind.position = SCNVector3(0.36, 0.24, -0.05)
        rightHind.scale = SCNVector3(0.8, 0.9, 1.2)
        breatheNode.addChildNode(rightHind)
        
        // ХВОСТ
        let tailRoot = SCNNode()
        tailRoot.name = "TailRoot"
        tailRoot.position = SCNVector3(0, 0.28, -0.42)
        
        let tailBaseGeo = SCNCylinder(radius: 0.075, height: 0.42)
        tailBaseGeo.firstMaterial = furMaterial
        let tailBase = SCNNode(geometry: tailBaseGeo)
        tailBase.position = SCNVector3(0, 0.18, 0)
        tailBase.eulerAngles = SCNVector3(-0.55, 0, 0)
        tailRoot.addChildNode(tailBase)
        
        let tailTipGeo = SCNSphere(radius: 0.09)
        tailTipGeo.firstMaterial = furWhiteMaterial
        let tailTip = SCNNode(geometry: tailTipGeo)
        tailTip.position = SCNVector3(0, 0.42, -0.15)
        tailRoot.addChildNode(tailTip)
        breatheNode.addChildNode(tailRoot)
        
        let tailWag = SCNAction.sequence([
            SCNAction.rotateBy(x: 0, y: 0.35, z: 0.15, duration: 1.2),
            SCNAction.rotateBy(x: 0, y: -0.70, z: -0.30, duration: 1.4),
            SCNAction.rotateBy(x: 0, y: 0.35, z: 0.15, duration: 1.2)
        ])
        tailRoot.runAction(SCNAction.repeatForever(tailWag))
        
        rootNode.addChildNode(catRoot)
        
        // ЖЕСТЫ: Поглаживание (Pan) и Тап (Tap)
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        scnView.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        guard let cat = uiView.scene?.rootNode.childNode(withName: "AiCatRoot", recursively: true) else { return }
        
        // 1. Обновляем визуальный гардероб в 3D
        updateOutfitVisibility(in: cat, currentOutfit: actionHandler.state.currentOutfit, isDressed: actionHandler.state.isDressed)
        
        // 2. Выполняем конечно-автоматную анимацию под уникальным токеном
        let token = actionHandler.state.executionToken
        if context.coordinator.lastExecutedToken == token { return }
        context.coordinator.lastExecutedToken = token
        
        executeCatAction(cat: cat, action: actionHandler.state.currentAction)
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
        
        glasses?.isHidden = !outfit.contains("очки") && !outfit.contains("худи") && !outfit.contains("кепка") && !outfit.contains("кулон")
        hoodie?.isHidden = !outfit.contains("худи")
        cap?.isHidden = !outfit.contains("кепка")
        pendant?.isHidden = !outfit.contains("кулон")
        
        // Под худи ошейник прячется
        collar?.isHidden = outfit.contains("худи")
        bell?.isHidden = outfit.contains("худи")
    }
    
    // SceneKit's built-in scale action only supports a uniform scalar.
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
        
        let head = cat.childNode(withName: "Head", recursively: true)
        let leftPaw = cat.childNode(withName: "LeftPaw", recursively: true)
        
        head?.removeAction(forKey: "head_action")
        leftPaw?.removeAction(forKey: "paw_action")
        
        // Сброс в абсолютное базовое положение (без накопления погрешностей!)
        cat.position = SCNVector3(0, 0, 0)
        cat.eulerAngles = SCNVector3(0, 0, 0)
        cat.scale = SCNVector3(1, 1, 1)
        leftPaw?.position = SCNVector3(-0.22, 0.22, 0.28)
        leftPaw?.eulerAngles = SCNVector3(0, 0, 0)
        head?.eulerAngles = SCNVector3(0, 0, 0)
        
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
            
        case .wash:
            if let paw = leftPaw, let h = head {
                let tiltHead = SCNAction.sequence([
                    SCNAction.rotateTo(x: 0.1, y: 0, z: 0.15, duration: 0.2),
                    SCNAction.wait(duration: 1.2),
                    SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.25)
                ])
                h.runAction(tiltHead, forKey: "head_action")
                
                let lift = SCNAction.move(to: SCNVector3(-0.16, 1.15, 0.45), duration: 0.25)
                lift.timingMode = .easeOut
                let scrub1 = SCNAction.rotateBy(x: 0.4, y: 0, z: 0.35, duration: 0.18)
                let scrub2 = SCNAction.rotateBy(x: -0.4, y: 0, z: -0.35, duration: 0.18)
                let drop = SCNAction.move(to: SCNVector3(-0.22, 0.22, 0.28), duration: 0.25)
                drop.timingMode = .easeIn
                
                let cycle = SCNAction.sequence([
                    lift,
                    scrub1, scrub2, scrub1, scrub2, scrub1, scrub2,
                    drop,
                    SCNAction.run { node in node.eulerAngles = SCNVector3(0, 0, 0) }
                ])
                paw.runAction(cycle, forKey: "paw_action")
            }
            
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
            
        case .play:
            let hop1 = SCNAction.move(to: SCNVector3(-0.15, 0.3, 0.1), duration: 0.2)
            let hop2 = SCNAction.move(to: SCNVector3(0.15, 0.3, 0.1), duration: 0.2)
            let returnFloor = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.2)
            cat.runAction(SCNAction.sequence([hop1, hop2, returnFloor]), forKey: "cat_action")
            
        case .sleep:
            let curlDown = SCNAction.group([
                scaleAction(to: SCNVector3(1.05, 0.85, 1.05), duration: 0.4),
                SCNAction.move(to: SCNVector3(0, -0.1, 0), duration: 0.4)
            ])
            cat.runAction(curlDown, forKey: "cat_action")
            
        case .dressUp:
            // Модный поворот на 360 градусов при примерке одежды
            let twirl = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 0.7)
            cat.runAction(twirl, forKey: "cat_action")
            
        default:
            break
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    @MainActor
    public class Coordinator: NSObject {
        var parent: Cat3DSceneView
        var lastExecutedToken: String = ""
        private var lastHapticTime: TimeInterval = 0
        
        init(_ parent: Cat3DSceneView) { self.parent = parent }
        
        // ПОГЛАЖИВАНИЕ СВАЙПОМ: плавное мурчание и тактильный отклик
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let now = Date().timeIntervalSince1970
            if now - lastHapticTime > 0.12 {
                lastHapticTime = now
                let softHaptic = UIImpactFeedbackGenerator(style: .soft)
                softHaptic.impactOccurred(intensity: 0.7)
            }
            
            if gesture.state == .ended {
                _ = TamagotchiManager.shared.petCat()
            }
        }
        
        // ТАП: быстрое почесывание за ушком
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            _ = TamagotchiManager.shared.petCat()
        }
    }
}
