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
        
        // 1. Студийный кинематографичный свет
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor(white: 1.0, alpha: 1.0)
        keyLight.light?.intensity = 1200
        keyLight.position = SCNVector3(x: 2.5, y: 4.5, z: 4.0)
        keyLight.eulerAngles = SCNVector3(-0.55, 0.45, 0)
        rootNode.addChildNode(keyLight)
        
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .omni
        rimLight.light?.color = UIColor.systemCyan
        rimLight.light?.intensity = 900
        rimLight.position = SCNVector3(x: -2.5, y: 2.0, z: -2.5)
        rootNode.addChildNode(rimLight)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.38, alpha: 1.0)
        rootNode.addChildNode(ambientLight)
        
        // Камера
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 1.05, z: 3.1)
        rootNode.addChildNode(cameraNode)
        
        // 2. Сборка реалистичного 3D-кота AiCat
        let catRoot = SCNNode()
        catRoot.name = "AiCatRoot"
        
        // Материалы
        let furDarkMaterial = SCNMaterial()
        furDarkMaterial.diffuse.contents = UIColor(red: 0.22, green: 0.24, blue: 0.30, alpha: 1.0) // Британский графитовый
        furDarkMaterial.roughness.contents = 0.55
        furDarkMaterial.specular.contents = UIColor(white: 0.25, alpha: 1.0)
        
        let furWhiteMaterial = SCNMaterial()
        furWhiteMaterial.diffuse.contents = UIColor(red: 0.92, green: 0.94, blue: 0.96, alpha: 1.0) // Белая манишка и лапки
        furWhiteMaterial.roughness.contents = 0.6
        
        let pinkMaterial = SCNMaterial()
        pinkMaterial.diffuse.contents = UIColor(red: 0.98, green: 0.58, blue: 0.68, alpha: 1.0) // Розовый носик и ушки
        
        let eyeMaterial = SCNMaterial()
        eyeMaterial.diffuse.contents = UIColor(red: 0.15, green: 0.88, blue: 0.45, alpha: 1.0) // Изумрудные кошачьи глаза
        eyeMaterial.emission.contents = UIColor(red: 0.05, green: 0.3, blue: 0.15, alpha: 1.0)
        
        let pupilMaterial = SCNMaterial()
        pupilMaterial.diffuse.contents = UIColor.black
        
        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 0.88)
        glassMaterial.metalness.contents = 0.85
        glassMaterial.roughness.contents = 0.1
        
        // --- ГОЛОВА ---
        let headGeo = SCNSphere(radius: 0.52)
        headGeo.firstMaterial = furDarkMaterial
        let headNode = SCNNode(geometry: headGeo)
        headNode.name = "Head"
        headNode.position = SCNVector3(0, 1.25, 0)
        catRoot.addChildNode(headNode)
        
        // --- ЩЕЧКИ КОТА (выразительная кошачья мордочка) ---
        let cheekGeo = SCNSphere(radius: 0.16)
        cheekGeo.firstMaterial = furWhiteMaterial
        
        let leftCheek = SCNNode(geometry: cheekGeo)
        leftCheek.position = SCNVector3(-0.13, 1.12, 0.40)
        catRoot.addChildNode(leftCheek)
        
        let rightCheek = SCNNode(geometry: cheekGeo)
        rightCheek.position = SCNVector3(0.13, 1.12, 0.40)
        catRoot.addChildNode(rightCheek)
        
        // --- РОЗОВЫЙ КОШАЧИЙ НОСИК ---
        let noseGeo = SCNSphere(radius: 0.065)
        noseGeo.firstMaterial = pinkMaterial
        let noseNode = SCNNode(geometry: noseGeo)
        noseNode.position = SCNVector3(0, 1.18, 0.49)
        catRoot.addChildNode(noseNode)
        
        // --- КОШАЧЬИ ГЛАЗА С ИЗУМРУДНОЙ РАДУЖКОЙ И ЗРАЧКАМИ ---
        let eyeGeo = SCNSphere(radius: 0.11)
        eyeGeo.firstMaterial = eyeMaterial
        
        let leftEye = SCNNode(geometry: eyeGeo)
        leftEye.position = SCNVector3(-0.20, 1.32, 0.40)
        catRoot.addChildNode(leftEye)
        
        let rightEye = SCNNode(geometry: eyeGeo)
        rightEye.position = SCNVector3(0.20, 1.32, 0.40)
        catRoot.addChildNode(rightEye)
        
        let pupilGeo = SCNCapsule(capRadius: 0.02, height: 0.12)
        pupilGeo.firstMaterial = pupilMaterial
        
        let leftPupil = SCNNode(geometry: pupilGeo)
        leftPupil.position = SCNVector3(-0.20, 1.32, 0.50)
        catRoot.addChildNode(leftPupil)
        
        let rightPupil = SCNNode(geometry: pupilGeo)
        rightPupil.position = SCNVector3(0.20, 1.32, 0.50)
        catRoot.addChildNode(rightPupil)
        
        // --- ЧЕРНЫЕ КИБЕР-ОЧКИ НА ПЕРЕНОСИЦЕ ---
        let glassesFrameGeo = SCNBox(width: 0.78, height: 0.22, length: 0.14, chamferRadius: 0.04)
        glassesFrameGeo.firstMaterial = glassMaterial
        let glassesNode = SCNNode(geometry: glassesFrameGeo)
        glassesNode.name = "Glasses"
        glassesNode.position = SCNVector3(0, 1.32, 0.49)
        catRoot.addChildNode(glassesNode)
        
        // Неоновая полоска на очках (фирменный стиль AiCat)
        let neonGeo = SCNBox(width: 0.74, height: 0.025, length: 0.15, chamferRadius: 0.01)
        neonGeo.firstMaterial?.diffuse.contents = UIColor.systemCyan
        neonGeo.firstMaterial?.emission.contents = UIColor.systemCyan
        let neonNode = SCNNode(geometry: neonGeo)
        neonNode.position = SCNVector3(0, 1.37, 0.50)
        catRoot.addChildNode(neonNode)
        
        // --- ТРЕУГОЛЬНЫЕ КОШАЧЬИ УШКИ С РОЗОВЫМИ ВСТАВКАМИ ---
        let earGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.19, height: 0.36)
        earGeo.firstMaterial = furDarkMaterial
        
        let leftEar = SCNNode(geometry: earGeo)
        leftEar.name = "LeftEar"
        leftEar.position = SCNVector3(-0.32, 1.74, 0.05)
        leftEar.eulerAngles = SCNVector3(0, 0, 0.28)
        catRoot.addChildNode(leftEar)
        
        let rightEar = SCNNode(geometry: earGeo)
        rightEar.name = "RightEar"
        rightEar.position = SCNVector3(0.32, 1.74, 0.05)
        rightEar.eulerAngles = SCNVector3(0, 0, -0.28)
        catRoot.addChildNode(rightEar)
        
        let innerEarGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.11, height: 0.26)
        innerEarGeo.firstMaterial = pinkMaterial
        
        let leftInnerEar = SCNNode(geometry: innerEarGeo)
        leftInnerEar.position = SCNVector3(-0.30, 1.72, 0.12)
        leftInnerEar.eulerAngles = SCNVector3(-0.12, 0, 0.28)
        catRoot.addChildNode(leftInnerEar)
        
        let rightInnerEar = SCNNode(geometry: innerEarGeo)
        rightInnerEar.position = SCNVector3(0.30, 1.72, 0.12)
        rightInnerEar.eulerAngles = SCNVector3(-0.12, 0, -0.28)
        catRoot.addChildNode(rightInnerEar)
        
        // --- БЕЛЫЕ ТОНКИЕ УСИКИ (по 3 с каждой стороны) ---
        let whiskerGeo = SCNCylinder(radius: 0.006, height: 0.40)
        whiskerGeo.firstMaterial?.diffuse.contents = UIColor.white
        
        let whiskerAngles: [Float] = [-0.15, 0.0, 0.15]
        for (i, angle) in whiskerAngles.enumerated() {
            let yOffset = Float(i) * Float(0.035)
            
            let lw = SCNNode(geometry: whiskerGeo)
            lw.position = SCNVector3(-0.35, Float(1.12) + yOffset, 0.38)
            lw.eulerAngles = SCNVector3(0, 0, Float.pi / Float(2) + angle)
            catRoot.addChildNode(lw)
            
            let rw = SCNNode(geometry: whiskerGeo)
            rw.position = SCNVector3(0.35, Float(1.12) + yOffset, 0.38)
            rw.eulerAngles = SCNVector3(0, 0, Float.pi / Float(2) - angle)
            catRoot.addChildNode(rw)
        }
        
        // --- ТЕЛО КОТА (пухлый котик с белой манишкой) ---
        let bodyGeo = SCNCapsule(capRadius: 0.44, height: 0.98)
        bodyGeo.firstMaterial = furDarkMaterial
        let bodyNode = SCNNode(geometry: bodyGeo)
        bodyNode.name = "Body"
        bodyNode.position = SCNVector3(0, 0.52, -0.05)
        catRoot.addChildNode(bodyNode)
        
        // Белая грудка
        let bibGeo = SCNSphere(radius: 0.32)
        bibGeo.firstMaterial = furWhiteMaterial
        let bibNode = SCNNode(geometry: bibGeo)
        bibNode.position = SCNVector3(0, 0.62, 0.22)
        bibNode.scale = SCNVector3(0.8, 1.1, 0.5)
        catRoot.addChildNode(bibNode)
        
        // Ошейник с кулоном
        let collarGeo = SCNCylinder(radius: 0.36, height: 0.04)
        collarGeo.firstMaterial?.diffuse.contents = UIColor.systemRed
        let collarNode = SCNNode(geometry: collarGeo)
        collarNode.position = SCNVector3(0, 0.88, 0.02)
        catRoot.addChildNode(collarNode)
        
        let bellGeo = SCNSphere(radius: 0.05)
        bellGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        bellGeo.firstMaterial?.metalness.contents = 0.9
        let bellNode = SCNNode(geometry: bellGeo)
        bellNode.position = SCNVector3(0, 0.84, 0.38)
        catRoot.addChildNode(bellNode)
        
        // --- ПЕРЕДНИЕ ЛАПКИ (с белыми носочками) ---
        let pawGeo = SCNCapsule(capRadius: 0.10, height: 0.40)
        pawGeo.firstMaterial = furWhiteMaterial
        
        let leftPaw = SCNNode(geometry: pawGeo)
        leftPaw.name = "LeftPaw"
        leftPaw.position = SCNVector3(-0.22, 0.22, 0.28)
        catRoot.addChildNode(leftPaw)
        
        let rightPaw = SCNNode(geometry: pawGeo)
        rightPaw.name = "RightPaw"
        rightPaw.position = SCNVector3(0.22, 0.22, 0.28)
        catRoot.addChildNode(rightPaw)
        
        // --- ЗАДНИЕ ЛАПКИ В ПОЗЕ СИДЯ ---
        let hindLegGeo = SCNSphere(radius: 0.24)
        hindLegGeo.firstMaterial = furDarkMaterial
        
        let leftHind = SCNNode(geometry: hindLegGeo)
        leftHind.position = SCNVector3(-0.36, 0.24, -0.05)
        leftHind.scale = SCNVector3(0.8, 0.9, 1.2)
        catRoot.addChildNode(leftHind)
        
        let rightHind = SCNNode(geometry: hindLegGeo)
        rightHind.position = SCNVector3(0.36, 0.24, -0.05)
        rightHind.scale = SCNVector3(0.8, 0.9, 1.2)
        catRoot.addChildNode(rightHind)
        
        // --- ПУШИСТЫЙ ХВОСТ С БЕЛЫМ КОНЧИКОМ ---
        let tailRoot = SCNNode()
        tailRoot.name = "TailRoot"
        tailRoot.position = SCNVector3(0, 0.28, -0.42)
        
        let tailBaseGeo = SCNCylinder(radius: 0.075, height: 0.42)
        tailBaseGeo.firstMaterial = furDarkMaterial
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
        
        // Анимация Idle: покачивание хвостом и мягкое дыхание
        let tailWag = SCNAction.sequence([
            SCNAction.rotateBy(x: 0, y: 0.35, z: 0.15, duration: 1.1),
            SCNAction.rotateBy(x: 0, y: -0.70, z: -0.30, duration: 1.4),
            SCNAction.rotateBy(x: 0, y: 0.35, z: 0.15, duration: 1.1)
        ])
        tailRoot.runAction(SCNAction.repeatForever(tailWag))
        
        let breathe = SCNAction.sequence([
            SCNAction.scale(to: 1.025, duration: 1.6),
            SCNAction.scale(to: 1.0, duration: 1.6)
        ])
        catRoot.runAction(SCNAction.repeatForever(breathe))
        
        // Легкое подергивание левого ушка раз в 5 секунд (живой кот)
        let earTwitch = SCNAction.sequence([
            SCNAction.wait(duration: 4.5),
            SCNAction.rotateBy(x: 0, y: 0, z: -0.18, duration: 0.08),
            SCNAction.rotateBy(x: 0, y: 0, z: 0.18, duration: 0.08),
            SCNAction.rotateBy(x: 0, y: 0, z: -0.12, duration: 0.06),
            SCNAction.rotateBy(x: 0, y: 0, z: 0.12, duration: 0.06)
        ])
        leftEar.runAction(SCNAction.repeatForever(earTwitch))
        
        rootNode.addChildNode(catRoot)
        
        // Обработка тапа по коту
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
            // Сальто назад с выпрыгиванием и вращением
            let crouch = SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.15)
            let jumpUp = SCNAction.moveBy(x: 0, y: 0.95, z: 0, duration: 0.35)
            jumpUp.timingMode = .easeOut
            let spin = SCNAction.rotateBy(x: -CGFloat(Double.pi * 2), y: 0, z: 0, duration: 0.6)
            let jumpDown = SCNAction.moveBy(x: 0, y: -0.80, z: 0, duration: 0.3)
            jumpDown.timingMode = .easeIn
            
            let sequence = SCNAction.sequence([crouch, SCNAction.group([jumpUp, spin]), jumpDown])
            cat.runAction(sequence)
            
        case .wash:
            // Лапка поднимается к мордочке и протирает щечку и ушко
            if let leftPaw = cat.childNode(withName: "LeftPaw", recursively: true) {
                let lift = SCNAction.move(to: SCNVector3(-0.15, 1.15, 0.45), duration: 0.22)
                let scrub1 = SCNAction.rotateBy(x: 0.35, y: 0, z: 0.35, duration: 0.18)
                let scrub2 = SCNAction.rotateBy(x: -0.35, y: 0, z: -0.35, duration: 0.18)
                let drop = SCNAction.move(to: SCNVector3(-0.22, 0.22, 0.28), duration: 0.22)
                
                let washCycle = SCNAction.sequence([lift, scrub1, scrub2, scrub1, scrub2, drop])
                leftPaw.runAction(washCycle)
            }
            
        case .hangOnIsland:
            // Кот прыгает наверх к Dynamic Island и раскачивается на лапках
            let leapUp = SCNAction.move(to: SCNVector3(0, 0.85, 0.3), duration: 0.4)
            leapUp.timingMode = .easeOut
            let swing = SCNAction.sequence([
                SCNAction.rotateBy(x: 0.18, y: 0, z: 0.1, duration: 0.5),
                SCNAction.rotateBy(x: -0.18, y: 0, z: -0.2, duration: 0.8),
                SCNAction.rotateBy(x: 0, y: 0, z: 0.1, duration: 0.5)
            ])
            let land = SCNAction.move(to: SCNVector3(0, 0, 0), duration: 0.35)
            land.timingMode = .easeIn
            
            cat.runAction(SCNAction.sequence([leapUp, swing, land]))
            
        case .play:
            // Кот делает бросок лапками вперед
            let pounce = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.2, z: 0.4, duration: 0.2),
                SCNAction.moveBy(x: 0, y: -0.2, z: -0.4, duration: 0.25)
            ])
            cat.runAction(pounce)
            
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
