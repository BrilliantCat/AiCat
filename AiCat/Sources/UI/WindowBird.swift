import SceneKit
import UIKit

/// A shallow scene between the painted skyline and the window mullions.
@MainActor
final class WindowBird {
    private let flock = SCNNode()
    private let tit = SCNNode()
    private let sparrow = SCNNode()
    private let titWing = SCNNode()
    private let sparrowWing = SCNNode()
    private var right = false
    private weak var watched: SCNNode?
    var visiblePosition: SIMD3<Float> { (watched ?? tit).presentation.simdWorldPosition }

    init(scene: SCNScene) {
        scene.rootNode.addChildNode(flock)

        func oval(_ size: SIMD3<Float>, _ at: SIMD3<Float>, _ color: UIColor, on parent: SCNNode) {
            let sphere = SCNSphere(radius: 1)
            sphere.segmentCount = 12
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = color
            sphere.firstMaterial = mat
            let node = SCNNode(geometry: sphere)
            node.simdScale = size
            node.simdPosition = at
            parent.addChildNode(node)
        }
        let slate = UIColor(red: 0.16, green: 0.25, blue: 0.32, alpha: 1)
        func addBird(_ bird: SCNNode, wing: SCNNode, belly: UIColor, feathers: UIColor, scale: Float) {
            flock.addChildNode(bird)
            bird.simdScale = SIMD3(repeating: scale)
            oval([0.11,0.071,0.012], .zero, belly, on: bird)
            oval([0.065,0.061,0.01], [0.077,0.066,0.004], feathers, on: bird)
            oval([0.045,0.015,0.006], [0.14,0.059,0.004], .darkGray, on: bird)
            oval([0.011,0.011,0.006], [0.10,0.078,0.014], .white, on: bird)
            oval([0.072,0.018,0.008], [-0.132,0.022,0], feathers, on: bird)
            bird.addChildNode(wing)
            wing.simdPosition = [0,0.015,0.011]
            oval([0.076,0.035,0.008], [-0.039,0,0], feathers, on: wing)
        }
        addBird(tit, wing: titWing, belly: .systemYellow, feathers: slate, scale: 1)
        addBird(sparrow, wing: sparrowWing, belly: .systemBrown, feathers: .darkGray, scale: 0.77)
        tit.simdPosition = Self.perch(false)
        sparrow.simdPosition = Self.perch(true)
        for side in [false,true] {
            let twig = SCNNode()
            twig.simdPosition = Self.perch(side) + SIMD3(0,-0.067,-0.004)
            flock.addChildNode(twig)
            oval([0.26,0.010,0.003], .zero, .brown, on: twig)
        }
    }

    private static func perch(_ right: Bool) -> SIMD3<Float> {
        CatRoomScenery.furnishing(right ? 0.30 : -1.35, right ? 2.16 : 1.53, -2.942)
    }

    func owns(_ node: SCNNode) -> Bool {
        var hit: SCNNode? = node
        while let n = hit {
            if n === tit || n === sparrow { watched = n; return true }
            if n === flock { return true }
            hit = n.parent
        }
        return false
    }

    func fly(reducedMotion: Bool) {
        guard tit.action(forKey: "flight") == nil, sparrow.action(forKey: "flight") == nil else { return }
        right.toggle()

        func cross(_ bird: SCNNode, wing: SCNNode, toRight: Bool, delay: Double, lift: Float) {
            let target = Self.perch(toRight)
            let start = bird.simdPosition
            bird.simdScale.x = abs(bird.simdScale.x) * (toRight ? 1 : -1)
            if reducedMotion {
                bird.simdPosition = target
                return
            }
            let flight = SCNAction.customAction(duration: 1.4) { node, seconds in
                let t = min(1, Float(seconds) / 1.4)
                let u = t*t*(3-2*t)
                node.simdPosition = start * (1-u) + target*u + SIMD3(0,lift*sin(.pi*t),0)
            }
            let beat = SCNAction.sequence([.rotateTo(x: 0, y: 0, z: -0.8, duration: 0.10),
                                           .rotateTo(x: 0, y: 0, z: 0, duration: 0.10)])
            wing.runAction(.sequence([.wait(duration: delay), .repeat(beat, count: 7)]))
            bird.runAction(.sequence([.wait(duration: delay), flight]), forKey: "flight")
        }
        cross(tit, wing: titWing, toRight: right, delay: 0, lift: 0.40)
        cross(sparrow, wing: sparrowWing, toRight: !right, delay: 0.23, lift: 0.19)
    }
}
