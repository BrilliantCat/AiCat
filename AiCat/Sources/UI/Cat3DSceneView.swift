import SwiftUI
import SceneKit

public struct Cat3DSceneView: UIViewRepresentable {
    @ObservedObject var actionHandler = CatActionHandler.shared
    
    public init() {}
    
    public func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = SCNScene()
        scnView.scene = scene
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.clear
        scnView.antialiasingMode = .multisampling4X
        
        let rootNode = scene.rootNode
        
        // 1. Освещение студийного уровня (Кинематографичный 3D-свет с неоновым контурным светом)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor(red: 1.0, green: 0.98, blue: 0.95, alpha: 1.0)
        keyLight.light?.intensity = 1400
        keyLight.position = SCNVector3(x: 2.0, y: 4.5, z: 4.0)
        keyLight.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        rootNode.addChildNode(keyLight)
        
        let cyanRim = SCNNode()
        cyanRim.light = SCNLight()
        cyanRim.light?.type = .omni
        cyanRim.light?.color = UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0)
        cyanRim.light?.intensity = 1100
        cyanRim.position = SCNVector3(x: -2.8, y: 2.2, z: -2.5)
        rootNode.addChildNode(cyanRim)
        
        let magentaFill = SCNNode()
        magentaFill.light = SCNLight()
        magentaFill.light?.type = .omni
        magentaFill.light?.color = UIColor(red: 0.8, green: 0.2, blue: 0.9, alpha: 1.0)
        magentaFill.light?.intensity = 600
        magentaFill.position = SCNVector3(x: 2.5, y: -1.0, z: 2.0)
        rootNode.addChildNode(magentaFill)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(red: 0.18, green: 0.22, blue: 0.30, alpha: 1.0)
        rootNode.addChildNode(ambientLight)
        
        // Камера
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0.95, z: 3.0)
        rootNode.addChildNode(cameraNode)
        
        // 2. Кибер-пьедестал с неоновыми кольцами под лапками кота
        let ringGeo = SCNTorus(ringRadius: 0.9, pipeRadius: 0.02)
        ringGeo.firstMaterial?.diffuse.contents = UIColor.systemCyan
        ringGeo.firstMaterial?.emission.contents = UIColor.systemCyan
        let ringNode = SCNNode(geometry: ringGeo)
        ringNode.position = SCNVector3(0, 0.02, 0)
        let ringRotate = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 8.0)
        ringNode.runAction(SCNAction.repeatForever(ringRotate))
        rootNode.addChildNode(ringNode)
        
        // 3. Персонаж: Стильный котик AiCat
        let catRoot = SCNNode()
        catRoot.name = "AiCatRoot"
        
        // Премиальные материалы
        let furMaterial = SCNMaterial()
        furMaterial.diffuse.contents = UIColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1.0) // Британский сапфирово-серый
        furMaterial.roughness.contents = 0.5
        furMaterial.specular.contents = UIColor(white: 0.3, alpha: 1.0)
        
        let furWhiteMaterial = SCNMaterial()
        furWhiteMaterial.diffuse.contents = UIColor(red: 0.94, green: 0.95, blue: 0.98, alpha: 1.0)
        furWhiteMaterial.roughness.contents = 0.6
        
        let pinkMaterial = SCNMaterial()
        pinkMaterial.diffuse.contents = UIColor(red: 0.98, green: 0.60, blue: 0.70, alpha: 1.0)
        
        let eyeMaterial = SCNMaterial()
        eyeMaterial.diffuse.contents = UIColor(red: 0.1, green: 0.95, blue: 0.5, alpha: 1.0) // Изумруд
        eyeMaterial.emission.contents = UIColor(red: 0.05, green: 0.35, blue: 0.15, alpha: 1.0)
        
        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.92)
        glassMaterial.metalness.contents = 0.9
        glassMaterial.roughness.contents = 0.05
        
        // --- ГОЛОВА ---
        let headGeo = SCNSphere(radius: 0.52)
        headGeo.firstMaterial = furMaterial
        let headNode = SCNNode(geometry: headGeo)
        headNode.name = "Head"
        headNode.position = SCNVector3(0, 1.25, 0)
        catRoot.addChildNode(headNode)
        
        // Щечки (выразительная мордочка)
        let cheekGeo = SCNSphere(radius: 0.16)
        cheekGeo.firstMaterial = furWhiteMaterial
        
        let leftCheek = SCNNode(geometry: cheekGeo)
        leftCheek.position = SCNVector3(-0.13, 1.12, 0.40)
        headNode.addChildNode(leftCheek)
        
        let rightCheek = SCNNode(geometry: cheekGeo)
        rightCheek.position = SCNVector3(0.13, 1.12, 0.40)
        headNode.addChildNode(rightCheek)
        
        // Носик
        let noseGeo = SCNSphere(radius: 0.065)
        noseGeo.firstMaterial = pinkMaterial
        let noseNode = SCNNode(geometry: noseGeo)
        noseNode.position = SCNVector3(0, 1.18, 0.49)
        headNode.addChildNode(noseNode)
        
        // Глаза с анимированными веками (мигание)
        let eyeGeo = SCNSphere(radius: 0.11)
        eyeGeo.firstMaterial = eyeMaterial
        
        let leftEye = SCNNode(geometry: eyeGeo)
        leftEye.position = SCNVector3(-0.20, 1.32, 0.40)
        headNode.addChildNode(leftEye)
        
        let rightEye = SCNNode(geometry: eyeGeo)
        rightEye.position = SCNVector3(0.20, 1.32, 0.40)
        headNode.addChildNode(rightEye)
        
        // Зрачки
        let pupilGeo = SCNCapsule(capRadius: 0.02, height: 0.11)
        pupilGeo.firstMaterial?.diffuse.contents = UIColor.black
        let leftPupil = SCNNode(geometry: pupilGeo)
        leftPupil.position = SCNVector3(-0.20, 1.32, 0.50)
        headNode.addChildNode(leftPupil)
        
        let rightPupil = SCNNode(geometry: pupilGeo)
        rightPupil.position = SCNVector3(0.20, 1.32, 0.50)
        headNode.addChildNode(rightPupil)
        
        // Анимация моргания глаз раз в 3.5 секунды
        let blinkAction = SCNAction.sequence([
            SCNAction.wait(duration: 3.5),
            SCNAction.scale(to: SCNVector3(1.0, 0.1, 1.0), duration: 0.08),
            SCNAction.scale(to: SCNVector3(1.0, 1.0, 1.0), duration: 0.08)
        ])
        leftEye.runAction(SCNAction.repeatForever(blinkAction))
        rightEye.runAction(SCNAction.repeatForever(blinkAction))
        
        // Кибер-очки на мордочке
        let glassesGeo = SCNBox(width: 0.76, height: 0.22, length: 0.14, chamferRadius: 0.04)
        glassesGeo.firstMaterial = glassMaterial
        let glassesNode = SCNNode(geometry: glassesGeo)
        glassesNode.name = "Glasses"
        glassesNode.position = SCNVector3(0, 1.32, 0.49)
        headNode.addChildNode(glassesNode)
        
        let neonStripGeo = SCNBox(width: 0.72, height: 0.025, length: 0.15, chamferRadius: 0.01)
        neonStripGeo.firstMaterial?.diffuse.contents = UIColor.systemCyan
        neonStripGeo.firstMaterial?.emission.contents = UIColor.systemCyan
        let neonNode = SCNNode(geometry: neonStripGeo)
        neonNode.position = SCNVector3(0, 1.37, 0.50)
        headNode.addChildNode(neonNode)
        
        // Ушки
        let earGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.19, height: 0.36)
        earGeo.firstMaterial = furMaterial
        
        let leftEar = SCNNode(geometry: earGeo)
        leftEar.name = "LeftEar"
        leftEar.position = SCNVector3(-0.32, 1.74, 0.05)
        leftEar.eulerAngles = SCNVector3(0, 0, 0.28)
        headNode.addChildNode(leftEar)
        
        let rightEar = SCNNode(geometry: earGeo)
        rightEar.name = "RightEar"
        rightEar.position = SCNVector3(0.32, 1.74, 0.05)
        rightEar.eulerAngles = SCNVector3(0, 0, -0.28)
        headNode.addChildNode(rightEar)
        
        let innerEarGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.11, height: 0.26)
        innerEarGeo.firstMaterial = pinkMaterial
        let leftInnerEar = SCNNode(geometry: innerEarGeo)
        leftInnerEar.position = SCNVector3(-0.30, 1.72, 0.12)
        leftInnerEar.eulerAngles = SCNVector3(-0.12, 0, 0.28)
        headNode.addChildNode(leftInnerEar)
        
        let rightInnerEar = SCNNode(geometry: innerEarGeo)
        rightInnerEar.position = SCNVector3(0.30, 1.72, 0.12)
        rightInnerEar.eulerAngles = SCNVector3(-0.12, 0, -0.28)
        headNode.addChildNode(rightInnerEar)
        
        // Усы
        let whiskerGeo = SCNCylinder(radius: 0.006, height: 0.40)
        whiskerGeo.firstMaterial?.diffuse.contents = UIColor.white
        let angles: [Float] = [-0.15, 0.0, 0.15]
        for (i, a) in angles.enumerated() {
            let yOff = Float(i) * Float(0.035)
            let lw = SCNNode(geometry: whiskerGeo)
            lw.position = SCNVector3(-0.35, Float(1.12) + yOff, 0.38)
            lw.eulerAngles = SCNVector3(0, 0, Float.pi / Float(2) + a)
            headNode.addChildNode(lw)
            
            let rw = SCNNode(geometry: whiskerGeo)
            rw.position = SCNVector3(0.35, Float(1.12) + yOff, 0.38)
            rw.eulerAngles = SCNVector3(0, 0, Float.pi / Float(2) - a)
            headNode.addChildNode(rw)
        }
        
        // --- ТЕЛО И ОШЕЙНИК ---
        let bodyGeo = SCNCapsule(capRadius: 0.44, height: 0.98)
        bodyGeo.firstMaterial = furMaterial
        let bodyNode = SCNNode(geometry: bodyGeo)
        bodyNode.name = "Body"
        bodyNode.position = SCNVector3(0, 0.52, -0.05)
        catRoot.addChildNode(bodyNode)
        
        let bibGeo = SCNSphere(radius: 0.32)
        bibGeo.firstMaterial = furWhiteMaterial
        let bibNode = SCNNode(geometry: bibGeo)
        bibNode.position = SCNVector3(0, 0.62, 0.22)
        bibNode.scale = SCNVector3(0.8, 1.1, 0.5)
        catRoot.addChildNode(bibNode)
        
        let collarGeo = SCNCylinder(radius: 0.36, height: 0.04)
        collarGeo.firstMaterial?.diffuse.contents = UIColor.systemRed
        let collarNode = SCNNode(geometry: collarGeo)
        collarNode.position = SCNVector3(0, 0.88, 0.02)
        catRoot.addChildNode(collarNode)
        
        let bellGeo = SCNSphere(radius: 0.06)
        bellGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        bellGeo.firstMaterial?.metalness.contents = 0.95
        let bellNode = SCNNode(geometry: bellGeo)
        bellNode.position = SCNVector3(0, 0.84, 0.38)
        catRoot.addChildNode(bellNode)
        
        // Лапки
        let pawGeo = SCNCapsule(capRadius: 0.10, height: 0.38)
        pawGeo.firstMaterial = furWhiteMaterial
        let leftPaw = SCNNode(geometry: pawGeo)
        leftPaw.name = "LeftPaw"
        leftPaw.position = SCNVector3(-0.22, 0.22, 0.28)
        catRoot.addChildNode(leftPaw)
        
        let rightPaw = SCNNode(geometry: pawGeo)
        rightPaw.name = "RightPaw"
        rightPaw.position = SCNVector3(0.22, 0.22, 0.28)
        catRoot.addChildNode(rightPaw)
        
        let hindGeo = SCNSphere(radius: 0.24)
        hindGeo.firstMaterial = furMaterial
        let leftHind = SCNNode(geometry: hindGeo)
        leftHind.position = SCNVector3(-0.36, 0.24, -0.05)
        leftHind.scale = SCNVector3(0.8, 0.9, 1.2)
        catRoot.addChildNode(leftHind)
        
        let rightHind = SCNNode(geometry: hindGeo)
        rightHind.position = SCNVector3(0.36, 0.24, -0.05)
        rightHind.scale = SCNVector3(0.8, 0.9, 1.2)
        catRoot.addChildNode(rightHind)
        
        // Хвост
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
        catRoot.addChildNode(tailRoot)
        
        // Анимации дыхания и хвоста (Idle)
        let tailWag = SCNAction.sequence([
            SCNAction.rotateBy(x: 0, y: 0.35, z: 0.15, duration: 1.2),
            SCNAction.rotateBy(x: 0, y: -0.70, z: -0.30, duration: 1.4),
            SCNAction.rotateBy(x: 0, y: 0.35, z: 0.15, duration: 1.2)
        ])
        tailRoot.runAction(SCNAction.repeatForever(tailWag))
        
        let breathe = SCNAction.sequence([
            SCNAction.scale(to: 1.025, duration: 1.6),
            SCNAction.scale(to: 1.0, duration: 1.6)
        ])
        catRoot.runAction(SCNAction.repeatForever(breathe))
        
        let earTwitch = SCNAction.sequence([
            SCNAction.wait(duration: 4.5),
            SCNAction.rotateBy(x: 0, y: 0, z: -0.18, duration: 0.08),
            SCNAction.rotateBy(x: 0, y: 0, z: 0.18, duration: 0.08)
        ])
        leftEar.runAction(SCNAction.repeatForever(earTwitch))
        
        rootNode.addChildNode(catRoot)
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        guard let cat = uiView.scene?.rootNode.childNode(withName: "AiCatRoot", recursively: true) else { return }
        
        let token = actionHandler.state.executionToken
        if context.coordinator.lastExecutedToken == token {
            return
        }
        context.coordinator.lastExecutedToken = token
        
        switch actionHandler.state.currentAction {
        case .somersault:
            // Плавное сальто назад с выпрыгиванием (squash & stretch)
            let crouch = SCNAction.scale(to: SCNVector3(1.15, 0.85, 1.15), duration: 0.12)
            let leapUp = SCNAction.moveBy(x: 0, y: 0.95, z: 0, duration: 0.35)
            leapUp.timingMode = .easeOut
            let spin = SCNAction.rotateBy(x: -CGFloat(Double.pi * 2), y: 0, z: 0, duration: 0.6)
            let stretch = SCNAction.scale(to: SCNVector3(0.9, 1.15, 0.9), duration: 0.25)
            let fallDown = SCNAction.moveBy(x: 0, y: -0.95, z: 0, duration: 0.3)
            fallDown.timingMode = .easeIn
            let bounceLand = SCNAction.sequence([
                SCNAction.scale(to: SCNVector3(1.1, 0.9, 1.1), duration: 0.08),
                SCNAction.scale(to: SCNVector3(1.0, 1.0, 1.0), duration: 0.12)
            ])
            
            let jumpGroup = SCNAction.group([leapUp, spin, stretch])
            let fullSomersault = SCNAction.sequence([crouch, jumpGroup, fallDown, bounceLand])
            cat.runAction(fullSomersault)
            
        case .wash:
            // Лапка плавно умывает мордочку 3 раза
            if let leftPaw = cat.childNode(withName: "LeftPaw", recursively: true),
               let head = cat.childNode(withName: "Head", recursively: true) {
                let tiltHead = SCNAction.sequence([
                    SCNAction.rotateBy(x: 0.1, y: 0, z: 0.15, duration: 0.2),
                    SCNAction.wait(duration: 1.2),
                    SCNAction.rotateBy(x: -0.1, y: 0, z: -0.15, duration: 0.2)
                ])
                head.runAction(tiltHead)
                
                let lift = SCNAction.move(to: SCNVector3(-0.15, 1.15, 0.45), duration: 0.25)
                lift.timingMode = .easeOut
                let scrub1 = SCNAction.rotateBy(x: 0.4, y: 0, z: 0.35, duration: 0.2)
                let scrub2 = SCNAction.rotateBy(x: -0.4, y: 0, z: -0.35, duration: 0.2)
                let drop = SCNAction.move(to: SCNVector3(-0.22, 0.22, 0.28), duration: 0.25)
                drop.timingMode = .easeIn
                
                let cycle = SCNAction.sequence([lift, scrub1, scrub2, scrub1, scrub2, scrub1, scrub2, drop])
                leftPaw.runAction(cycle)
            }
            
        case .hangOnIsland:
            // Кот прыгает наверх к острову и раскачивается как маятник
            let jumpToIsland = SCNAction.move(to: SCNVector3(0, 1.0, 0.4), duration: 0.4)
            jumpToIsland.timingMode = .easeOut
            let swing = SCNAction.sequence([
                SCNAction.rotateBy(x: 0.15, y: 0, z: 0.12, duration: 0.45),
                SCNAction.rotateBy(x: -0.15, y: 0, z: -0.24, duration: 0.7),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.12, duration: 0.45)
            ])
            let landDown = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.35)
            landDown.timingMode = .easeIn
            
            cat.runAction(SCNAction.sequence([jumpToIsland, swing, landDown]))
            
        default:
            break
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject {
        var parent: Cat3DSceneView
        var lastExecutedToken: String = ""
        
        init(_ parent: Cat3DSceneView) { self.parent = parent }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            _ = TamagotchiManager.shared.petCat()
            _ = self.parent.actionHandler.execute(action: "wash")
        }
    }
}
