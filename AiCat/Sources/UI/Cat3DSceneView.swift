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
        scnView.autoenablesDefaultLighting = true
        scnView.backgroundColor = UIColor.clear
        
        // Создаем базовый 3D-меш котика (тело, голова, ушки, очки)
        let rootNode = scene.rootNode
        
        // Камера
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 1.2, z: 3.5)
        rootNode.addChildNode(cameraNode)
        
        // Освещение (Tech Cyber Ambient)
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.light?.color = UIColor.systemCyan
        lightNode.position = SCNVector3(x: 2, y: 3, z: 2)
        rootNode.addChildNode(lightNode)
        
        // Контейнер персонажа
        let catNode = SCNNode()
        catNode.name = "AiCatRoot"
        
        // 1. Голова кота
        let headGeometry = SCNSphere(radius: 0.6)
        headGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.25, green: 0.27, blue: 0.32, alpha: 1.0)
        let headNode = SCNNode(geometry: headGeometry)
        headNode.position = SCNVector3(0, 1.2, 0)
        catNode.addChildNode(headNode)
        
        // 2. Ушки кота (конусы)
        let earGeometry = SCNCone(topRadius: 0.0, bottomRadius: 0.18, height: 0.35)
        earGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.22, blue: 0.26, alpha: 1.0)
        
        let leftEar = SCNNode(geometry: earGeometry)
        leftEar.position = SCNVector3(-0.35, 1.75, 0.05)
        leftEar.eulerAngles = SCNVector3(0, 0, 0.25)
        catNode.addChildNode(leftEar)
        
        let rightEar = SCNNode(geometry: earGeometry)
        rightEar.position = SCNVector3(0.35, 1.75, 0.05)
        rightEar.eulerAngles = SCNVector3(0, 0, -0.25)
        catNode.addChildNode(rightEar)
        
        // 3. Крутые темные очки (Фирменный атрибут AiCat)
        let glassesGeometry = SCNBox(width: 0.75, height: 0.22, length: 0.15, chamferRadius: 0.04)
        glassesGeometry.firstMaterial?.diffuse.contents = UIColor.black
        glassesGeometry.firstMaterial?.metalness.contents = 0.9
        glassesGeometry.firstMaterial?.roughness.contents = 0.1
        let glassesNode = SCNNode(geometry: glassesGeometry)
        glassesNode.name = "Sunglasses"
        glassesNode.position = SCNVector3(0, 1.25, 0.55)
        catNode.addChildNode(glassesNode)
        
        // 4. Тело кота
        let bodyGeometry = SCNCapsule(capRadius: 0.5, height: 1.1)
        bodyGeometry.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1.0)
        let bodyNode = SCNNode(geometry: bodyGeometry)
        bodyNode.position = SCNVector3(0, 0.35, 0)
        catNode.addChildNode(bodyNode)
        
        // 5. Передние лапки
        let pawGeometry = SCNCapsule(capRadius: 0.12, height: 0.45)
        pawGeometry.firstMaterial?.diffuse.contents = UIColor.white
        
        let leftPaw = SCNNode(geometry: pawGeometry)
        leftPaw.name = "LeftPaw"
        leftPaw.position = SCNVector3(-0.25, 0.1, 0.35)
        catNode.addChildNode(leftPaw)
        
        let rightPaw = SCNNode(geometry: pawGeometry)
        rightPaw.name = "RightPaw"
        rightPaw.position = SCNVector3(0.25, 0.1, 0.35)
        catNode.addChildNode(rightPaw)
        
        rootNode.addChildNode(catNode)
        
        // Добавляем жестовые реакции (погладить кота)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        return scnView
    }
    
    public func updateUIView(_ uiView: SCNView, context: Context) {
        guard let catNode = uiView.scene?.rootNode.childNode(withName: "AiCatRoot", recursively: true) else { return }
        
        // Анимации при смене состояний
        switch actionHandler.state.currentAction {
        case .somersault:
            let spin = SCNAction.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 0.8)
            catNode.runAction(spin)
            
        case .hangOnIsland:
            let reachUp = SCNAction.move(to: SCNVector3(0, 0.8, 0), duration: 0.5)
            catNode.runAction(reachUp)
            
        case .wash:
            if let leftPaw = catNode.childNode(withName: "LeftPaw", recursively: true) {
                let washAction = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.3, z: 0.2, duration: 0.25),
                    SCNAction.moveBy(x: 0, y: -0.3, z: -0.2, duration: 0.25)
                ])
                leftPaw.runAction(SCNAction.repeat(washAction, count: 3))
            }
            
        default:
            break
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject {
        var parent: Cat3DSceneView
        
        init(_ parent: Cat3DSceneView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            // Реакция на поглаживание: легкая вибрация и мурчание
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            _ = self.parent.actionHandler.execute(action: "wash")
        }
    }
}
