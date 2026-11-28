import SceneKit
import UIKit

/// Room props are built once. The mouse moves on the same floor as the kitten.
@MainActor
final class RoomVisitors {
    let mouse = SCNNode()
    let burrow = SIMD3<Float>(2.78, 0, -2.98)
    private let root: SCNNode
    private var tail: SCNNode?
    private var elapsed: Float = 0
    private var lastPoint = SIMD3<Float>.zero
    private var path: [SIMD3<Float>] = []
    let captionAnchor = SIMD3<Float>(1.97, 3.02, -2.92)

    init(scene: SCNScene) {
        root = scene.rootNode
        for (x, art) in [(-3.24, "StreetNight"), (1.97, "StreetDay")] {
            let frame = SCNBox(width: 1.63, height: 1.12, length: 0.07, chamferRadius: 0.03)
            frame.firstMaterial?.diffuse.contents = UIColor.brown
            let node = SCNNode(geometry: frame)
            node.simdPosition = [Float(x), 3.24, -3.025]
            root.addChildNode(node)
            if let url = Bundle.main.url(forResource: art, withExtension: "jpg", subdirectory: "LivingRoom") {
                let canvas = SCNPlane(width: 1.51, height: 1.01)
                canvas.firstMaterial?.diffuse.contents = UIImage(contentsOfFile: url.path)
                canvas.firstMaterial?.lightingModel = .constant
                let printNode = SCNNode(geometry: canvas)
                printNode.position.z = 0.04
                node.addChildNode(printNode)
            }
        }
        let basket = SCNCylinder(radius: 0.34, height: 0.43)
        basket.firstMaterial?.diffuse.contents = UIColor(red: 0.63, green: 0.36, blue: 0.19, alpha: 1)
        let basketNode = SCNNode(geometry: basket)
        basketNode.simdPosition = [-2.64,0.215,-1.7]
        root.addChildNode(basketNode)
        func oval(_ parent: SCNNode, _ at: SIMD3<Float>, _ scale: SIMD3<Float>, _ color: UIColor) -> SCNNode {
            let mesh = SCNSphere(radius: 1)
            mesh.segmentCount = 12
            mesh.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: mesh)
            node.simdPosition = at
            node.simdScale = scale
            parent.addChildNode(node)
            return node
        }
        let planter = SCNNode(geometry: SCNCone(topRadius: 0.23, bottomRadius: 0.15, height: 0.38))
        planter.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.65, green: 0.33, blue: 0.23, alpha: 1)
        planter.simdPosition = [2.38,0.19,-2.45]
        root.addChildNode(planter)
        for i in 0..<9 {
            let angle = Float(i) * 2.4
            let leaf = oval(planter,[0.14*cos(angle),0.40,0.14*sin(angle)], [0.071,0.26,0.044],
                            UIColor(red: 0.26, green: 0.49, blue: 0.32, alpha: 1))
            leaf.simdEulerAngles = [0.56*sin(angle),0,-0.56*cos(angle)]
        }
        let hole = oval(root, burrow + SIMD3(0,0.08,0), [0.16,0.14,0.025], .black)
        hole.name = "MouseDoor"
        root.addChildNode(mouse)
        mouse.isHidden = true
        let fur = UIColor.systemGray
        _ = oval(mouse,[0,0.075,0],[0.075,0.072,0.14],fur)
        _ = oval(mouse,[0,0.092,0.115],[0.058,0.054,0.074],fur)
        for side: Float in [-1,1] {
            _ = oval(mouse,[side*0.044,0.15,0.10],[0.029,0.036,0.014],.systemPink)
            _ = oval(mouse,[side*0.04,0.105,0.16],[0.009,0.010,0.009],.black)
        }
        tail = oval(mouse,[0,0.035,-0.19],[0.012,0.012,0.10],.systemPink)
    }

    func start() {
        elapsed = 0
        lastPoint = burrow
        let offset = Float.random(in: -0.28...0.28)
        path = [burrow,[2.75,0,-0.85],[1.1,0,0.8+offset],[-1.7,0,0.1],[-2.25,0,1.1],
                [0.4,0,1.6+offset],[2.75,0,-0.85],burrow]
        mouse.simdPosition = burrow
        mouse.isHidden = false
    }

    func advance(_ dt: Float, chasedBy cat: SIMD3<Float>) -> SIMD3<Float>? {
        let separation = simd_distance(SIMD2(cat.x,cat.z), SIMD2(lastPoint.x,lastPoint.z))
        elapsed += dt * (separation < 0.7 ? 1.45 : 0.92)
        tail?.eulerAngles.y = 0.25 * sin(elapsed * 16)
        let segment = Int(elapsed / 1.15)
        guard segment + 1 < path.count else { mouse.isHidden = true; return nil }
        let t = elapsed / 1.15 - Float(segment)
        let next = path[segment] + (path[segment+1]-path[segment]) * t
        let delta = next - lastPoint
        if abs(delta.x) + abs(delta.z) > 0.0001 { mouse.eulerAngles.y = atan2(delta.x,delta.z) }
        mouse.simdPosition = next + SIMD3(0,0.012*abs(sin(elapsed*20)),0)
        lastPoint = next
        return next
    }
}
