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
        
        // 1. Освещение студийного уровня (Кинематографичный 3D-свет)
        let mainLight = SCNNode()
        mainLight.light = SCNLight()
        mainLight.light?.type = .directional
        mainLight.light?.color = UIColor.white
        mainLight.light?.intensity = 1000
        mainLight.position = SCNVector3(x: 2, y: 4, z: 4)
        mainLight.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        rootNode.addChildNode(mainLight)
        
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .omni
        rimLight.light?.color = UIColor.systemCyan
        rimLight.light?.intensity = 800
        rimLight.position = SCNVector3(x: -2, y: 2, z: -2)
        rootNode.addChildNode(rimLight)
        
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.35, alpha: 1.0)
        rootNode.addChildNode(ambientLight)
        
        // Камера
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 1.1, z: 3.2)
        rootNode.addChildNode(cameraNode)
        
        // 2. Персонаж: Кот AiCat
        let catRoot = SCNNode()
        catRoot.name = "AiCatRoot"
        
        // Материалы
        let furMaterial = SCNMaterial()
        furMaterial.diffuse.contents = UIColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1.0) // Глубокий британский серый
        furMaterial.roughness.contents = 0.6
        furMaterial.specular.contents = UIColor(white: 0.2, alpha: 1.0)
        
        let pinkMaterial = SCNMaterial()
        pinkMaterial.diffuse.contents = UIColor(red: 0.95, green: 0.55, blue: 0.65, alpha: 1.0) // Розовый носик и ушки
        
        let glassMaterial = SCNMaterial()
        glassMaterial.diffuse.contents = UIColor.black
        glassMaterial.metalness.contents = 0.95
        glassMaterial.roughness.contents = 0.05
        
        // Голова кота
        let headGeo = SCNSphere(radius: 0.58)
        headGeo.firstMaterial = furMaterial
        let headNode = SCNNode(geometry: headGeo)
        headNode.name = "Head"
        headNode.position = SCNVector3(0, 1.25, 0)
        catRoot.addChildNode(headNode)
        
        // Ушки (внешняя и внутренняя часть)
        let earGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.2, height: 0.38)
        earGeo.firstMaterial = furMaterial
        
        let leftEar = SCNNode(geometry: earGeo)
        leftEar.name = "LeftEar"
        leftEar.position = SCNVector3(-0.35, 1.78, 0.02)
        leftEar.eulerAngles = SCNVector3(0, 0, 0.25)
        catRoot.addChildNode(leftEar)
        
        let rightEar = SCNNode(geometry: earGeo)
        rightEar.name = "RightEar"
        rightEar.position = SCNVector3(0.35, 1.78, 0.02)
        rightEar.eulerAngles = SCNVector3(0, 0, -0.25)
        catRoot.addChildNode(rightEar)
        
        // Розовые вставки внутрь ушей
        let innerEarGeo = SCNCone(topRadius: 0.01, bottomRadius: 0.12, height: 0.28)
        innerEarGeo.firstMaterial = pinkMaterial
        let leftInner = SCNNode(geometry: innerEarGeo)
        leftInner.position = SCNVector3(-0.33, 1.76, 0.08)
        leftInner.eulerAngles = SCNVector3(-0.1, 0, 0.25)
        catRoot.addChildNode(leftInner)
        
        let rightInner = SCNNode(geometry: innerEarGeo)
        rightInner.position = SCNVector3(0.33, 1.76, 0.08)
        rightInner.eulerAngles = SCNVector3(-0.1, 0, -0.25)
        catRoot.addChildNode(rightInner)
        
        // Щечки кота (мордочка)
        let cheekGeo = SCNSphere(radius: 0.16)
        cheekGeo.firstMaterial = furMaterial
        let leftCheek = SCNNode(geometry: cheekGeo)
        leftCheek.position = SCNVector3(-0.12, 1.12, 0.45)
        catRoot.addChildNode(leftCheek)
        
        let rightCheek = SCNNode(geometry: cheekGeo)
        rightCheek.position = SCNVector3(0.12, 1.12, 0.45)
        catRoot.addChildNode(rightCheek)
        
        // Носик (розовый треугольник/сфера)
        let noseGeo = SCNSphere(radius: 0.07)
        noseGeo.firstMaterial = pinkMaterial
        let noseNode = SCNNode(geometry: noseGeo)
        noseNode.position = SCNVector3(0, 1.18, 0.54)
        catRoot.addChildNode(noseNode)
        
        // Черные кибер-очки
        let glassesGeo = SCNBox(width: 0.85, height: 0.24, length: 0.18, chamferRadius: 0.05)
        glassesGeo.firstMaterial = glassMaterial
        let glassesNode = SCNNode(geometry: glassesGeo)
        glassesNode.name = "Glasses"
        glassesNode.position = SCNVector3(0, 1.34, 0.52)
        catRoot.addChildNode(glassesNode)
        
        // Неоновый отблеск на очках (фирменный стиль AiCat)
        let neonStripGeo = SCNBox(width: 0.78, height: 0.03, length: 0.19, chamferRadius: 0.01)
        neonStripGeo.firstMaterial?.diffuse.contents = UIColor.systemCyan
        neonStripGeo.firstMaterial?.emission.contents = UIColor.systemCyan
        let neonStrip = SCNNode(geometry: neonStripGeo)
        neonStrip.position = SCNVector3(0, 1.37, 0.53)
        catRoot.addChildNode(neonStrip)
        
        // Усы (белые тонкие цилиндры)
        let whiskerGeo = SCNCylinder(radius: 0.008, height: 0.45)
        whiskerGeo.firstMaterial?.diffuse.contents = UIColor.white
        
        let leftW1 = SCNNode(geometry: whiskerGeo)
        leftW1.position = SCNVector3(-0.35, 1.12, 0.42)
        leftW1.eulerAngles = SCNVector3(0, 0, Float.pi / 2 + Float(0.1))
        catRoot.addChildNode(leftW1)
        
        let rightW1 = SCNNode(geometry: whiskerGeo)
        rightW1.position = SCNVector3(0.35, 1.12, 0.42)
        rightW1.eulerAngles = SCNVector3(0, 0, Float.pi / 2 - Float(0.1))
        catRoot.addChildNode(rightW1)
        
        // Тело кота (пухлый котик)
        let bodyGeo = SCNCapsule(capRadius: 0.48, height: 1.05)
        bodyGeo.firstMaterial = furMaterial
        let bodyNode = SCNNode(geometry: bodyGeo)
        bodyNode.name = "Body"
        bodyNode.position = SCNVector3(0, 0.48, -0.05)
        catRoot.addChildNode(bodyNode)
        
        // Передние лапки
        let pawGeo = SCNCapsule(capRadius: 0.11, height: 0.42)
        pawGeo.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.25, blue: 0.3, alpha: 1.0)
        
        let leftPaw = SCNNode(geometry: pawGeo)
        leftPaw.name = "LeftPaw"
        leftPaw.position = SCNVector3(-0.24, 0.2, 0.32)
        catRoot.addChildNode(leftPaw)
        
        let rightPaw = SCNNode(geometry: pawGeo)
        rightPaw.name = "RightPaw"
        rightPaw.position = SCNVector3(0.24, 0.2, 0.32)
        catRoot.addChildNode(rightPaw)
        
        // Пушистый хвост с анимацией покачивания
        let tailGeo = SCNCylinder(radius: 0.08, height: 0.7)
        tailGeo.firstMaterial = furMaterial
        let tailNode = SCNNode(geometry: tailGeo)
        tailNode.name = "Tail"
        tailNode.position = SCNVector3(0, 0.35, -0.55)
        tailNode.eulerAngles = SCNVector3(-0.6, 0, 0)
        catRoot.addChildNode(tailNode)
        
        // Анимация дыхания и виляния хвостом (Idle)
        let tailWag = SCNAction.sequence([
            SCNAction.rotateBy(x: 0, y: 0, z: 0.2, duration: 1.2),
            SCNAction.rotateBy(x: 0, y: 0, z: -0.4, duration: 1.2),
            SCNAction.rotateBy(x: 0, y: 0, z: 0.2, duration: 1.2)
        ])
        tailNode.runAction(SCNAction.repeatForever(tailWag))
        
        let breathe = SCNAction.sequence([
            SCNAction.scale(to: 1.03, duration: 1.5),
            SCNAction.scale(to: 1.0, duration: 1.5)
        ])
        catRoot.runAction(SCNAction.repeatForever(breathe))
        
        rootNode.addChildNode(catRoot)
        
        // Жест поглаживания
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        guard let cat = uiView.scene?.rootNode.childNode(withName: "AiCatRoot", recursively: true) else { return }
        
        switch actionHandler.state.currentAction {
        case .somersault:
            // Сальто назад с прыжком вверх
            let jumpUp = SCNAction.moveBy(x: 0, y: 0.8, z: 0, duration: 0.35)
            jumpUp.timingMode = .easeOut
            let jumpDown = SCNAction.moveBy(x: 0, y: -0.8, z: 0, duration: 0.35)
            jumpDown.timingMode = .easeIn
            let spin = SCNAction.rotateBy(x: -CGFloat(Double.pi * 2), y: 0, z: 0, duration: 0.7)
            
            let jump = SCNAction.sequence([jumpUp, jumpDown])
            cat.runAction(SCNAction.group([jump, spin]))
            
        case .wash:
            // Лапка поднимается к щеке и умывается 3 раза
            if let leftPaw = cat.childNode(withName: "LeftPaw", recursively: true) {
                let washCycle = SCNAction.sequence([
                    SCNAction.move(to: SCNVector3(-0.15, 1.15, 0.45), duration: 0.2),
                    SCNAction.rotateBy(x: 0.3, y: 0, z: 0.3, duration: 0.2),
                    SCNAction.rotateBy(x: -0.3, y: 0, z: -0.3, duration: 0.2),
                    SCNAction.move(to: SCNVector3(-0.24, 0.2, 0.32), duration: 0.2)
                ])
                leftPaw.runAction(washCycle)
            }
            
        case .hangOnIsland:
            // Подтягивание лапками вверх
            let hang = SCNAction.sequence([
                SCNAction.move(to: SCNVector3(0, 0.6, 0.2), duration: 0.4),
                SCNAction.rotateBy(x: 0.2, y: 0, z: 0, duration: 0.4)
            ])
            cat.runAction(hang)
            
        default:
            break
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject {
        var parent: Cat3DSceneView
        init(_ parent: Cat3DSceneView) { self.parent = parent }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
            _ = TamagotchiManager.shared.petCat()
            _ = self.parent.actionHandler.execute(action: "wash")
        }
    }
}
