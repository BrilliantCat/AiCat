import SceneKit
import simd
import UIKit

enum CatMotion: String, CaseIterable {
    case idle, walk, trot, purr, play, sleep, eat, groom, think, talk, pushUp, squat, plank, yoga, stretch, curl, scan, computer, breath, shoulders

    var isExercise: Bool {
        switch self {
        case .pushUp, .squat, .plank, .yoga, .stretch, .curl, .breath, .shoulders: return true
        default: return false
        }
    }
}

final class CatMotionRig {
    private let model: CatBodyMesh.Description
    private let bones: [SCNNode]
    private let rest: [SIMD3<Float>]
    private var rotations: [simd_quatf]
    private var previous: [simd_quatf]
    private var rootOffset = SIMD3<Float>.zero
    private var previousRoot = SIMD3<Float>.zero
    private var eyes: Float = 1
    private var previousEyes: Float = 1
    private var elapsed: Float = 0
    private var blendTime: Float = 0
    private var blinkClock: Float = 0
    private var motion: CatMotion = .idle
    private var props: [CatMotion: SCNNode] = [:]
    private let headIndex: Int
    private let eyeIndices: [Int]
    var gaze = SIMD2<Float>.zero

    init?(cat: SCNNode) {
        guard let asset = CatBodyMesh.asset,
              let head = asset.description.bones.firstIndex(of: "head") else { return nil }
        model = asset.description
        headIndex = head
        eyeIndices = model.bones.indices.filter { asset.description.bones[$0].hasPrefix("eye") }
        let origins = model.origins.map { SIMD3<Float>($0[0], $0[1], $0[2]) }
        let nodes = model.bones.map { name -> SCNNode in
            let bone = SCNNode()
            bone.name = name
            return bone
        }
        var offsets = origins
        for i in nodes.indices {
            let p = model.parents[i]
            if p >= 0 { offsets[i] -= origins[p] }
            nodes[i].simdPosition = offsets[i]
            (p < 0 ? cat : nodes[p]).addChildNode(nodes[i])
        }
        bones = nodes
        rest = offsets
        rotations = Array(repeating: simd_quatf(real: 1, imag: .zero), count: nodes.count)
        previous = rotations
        let inverseBind = origins.map { origin -> NSValue in
            NSValue(scnMatrix4: SCNMatrix4MakeTranslation(-origin.x, -origin.y, -origin.z))
        }
        let skin = SCNSkinner(baseGeometry: asset.geometry, bones: nodes, boneInverseBindTransforms: inverseBind,
                              boneWeights: asset.weights, boneIndices: asset.indices)
        skin.skeleton = nodes[0]
        let surface = SCNNode(geometry: asset.geometry)
        surface.name = "BritishKittenSkin"
        surface.skinner = skin
        cat.addChildNode(surface)
        installProps(in: cat)
        set(.idle, reduced: true)
    }

    private func installProps(in cat: SCNNode) {
        func prop(_ mesh: SCNGeometry, _ color: UIColor, _ p: SIMD3<Float>, _ parent: SCNNode) -> SCNNode {
            let mat = SCNMaterial()
            mat.diffuse.contents = color
            mesh.firstMaterial = mat
            let node = SCNNode(geometry: mesh)
            node.simdPosition = p
            parent.addChildNode(node)
            return node
        }
        let glaze = UIColor(red: 0.43, green: 0.59, blue: 0.55, alpha: 1)
        let bowl = prop(SCNCylinder(radius: 0.19, height: 0.036), glaze, [0,0.021,0.78], cat)
        _ = prop(SCNTorus(ringRadius: 0.172, pipeRadius: 0.022), glaze, [0,0.027,0], bowl)
        for i in 0..<8 {
            let a = Float(i) * 2.4
            let kibble = prop(SCNSphere(radius: 0.034), .brown, [cos(a)*0.071,0.037,sin(a)*0.071], bowl)
            kibble.simdScale.y = 0.55
        }
        let base = prop(SCNBox(width: 0.65, height: 0.045, length: 0.43, chamferRadius: 0.015), .brown, [0,0.189,0.67], cat)
        for x: Float in [-0.26,0.26] {
            for z: Float in [-0.155,0.155] {
                _ = prop(SCNCylinder(radius: 0.021, height: 0.17), .brown, [x,-0.105,z], base)
            }
        }
        let laptop = prop(SCNBox(width: 0.54, height: 0.025, length: 0.35, chamferRadius: 0.014), .darkGray, [0,0.036,0], base)
        let keyboard = SCNPlane(width: 0.45, height: 0.19)
        let keys = prop(keyboard, .darkGray, [0,0.014,-0.01], laptop)
        keys.eulerAngles.x = -.pi/2
        keyboard.firstMaterial?.diffuse.contents = Self.keyboardTexture
        let lid = prop(SCNBox(width: 0.54, height: 0.31, length: 0.022, chamferRadius: 0.012), .darkGray, [0,0.15,0.17], laptop)
        lid.eulerAngles.x = 0.15
        _ = prop(SCNPlane(width: 0.49,height: 0.265), .systemIndigo, [0,0,-0.015], lid)
        lid.childNodes.last?.eulerAngles.y = .pi
        let scanner = prop(SCNTorus(ringRadius: 0.44, pipeRadius: 0.008), .systemMint, [0,0.18,0], cat)
        props = [.eat: bowl, .computer: base, .scan: scanner]
        for prop in props.values { prop.isHidden = true }
    }

    private static let keyboardTexture: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 144, height: 60), format: format).image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 144, height: 60))
            UIColor(white: 0.16, alpha: 1).setFill()
            for row in 0..<4 {
                for col in 0..<12 {
                    context.fill(CGRect(x: CGFloat(1 + col * 12), y: CGFloat(1 + row * 15), width: 10, height: 12))
                }
            }
        }
    }()

    func set(_ next: CatMotion, reduced: Bool) {
        if next != motion {
            previous = rotations
            previousRoot = rootOffset
            previousEyes = eyes
            elapsed = 0
            blendTime = 0
            motion = next
            for (key, prop) in props { prop.isHidden = key != next }
        }
        if reduced {
            elapsed = model.clips[next.rawValue]?.entry?.seconds ?? 0
            blendTime = 0.36
            render(time: elapsed, blend: 1, blink: 1)
        }
    }

    func advance(by dt: Float, strideRate: Float = 1, breathPhase: Float? = nil) {
        elapsed += (motion == .walk || motion == .trot) ? dt * strideRate : dt
        if motion == .breath, let breathPhase, let clip = model.clips[motion.rawValue] {
            elapsed = clip.seconds * breathPhase
        }
        blendTime += dt
        blinkClock = (blinkClock + dt).truncatingRemainder(dividingBy: 4.3)
        let blink = min(1, max(0.06, abs(blinkClock - 3.86) / 0.09))
        let blend = min(1, blendTime / 0.36)
        render(time: elapsed, blend: blend * blend * (3 - 2 * blend), blink: blink)
    }

    private func render(time: Float, blend: Float, blink: Float) {
        guard let clip = model.clips[motion.rawValue] else { return }
        let frames: [[Float]]
        let at: Float
        if let entry = clip.entry, time < entry.seconds {
            frames = entry.frames
            at = time / entry.seconds * Float(frames.count - 1)
        } else {
            frames = clip.frames
            let loopTime = time - (clip.entry?.seconds ?? 0)
            at = loopTime.truncatingRemainder(dividingBy: clip.seconds) / clip.seconds * Float(frames.count)
        }
        let index = Int(at) % frames.count
        let fraction = at - floor(at)
        let a = frames[index], b = frames[(index + 1) % frames.count]
        func sample(_ k: Int) -> Float { a[k] + (b[k] - a[k]) * fraction }
        rootOffset = previousRoot + (SIMD3<Float>(sample(0), sample(1), sample(2)) - previousRoot) * blend
        bones[0].simdPosition = rest[0] + rootOffset
        eyes = previousEyes + (sample(3) - previousEyes) * blend
        let openness = min(eyes, blink)
        for i in bones.indices {
            let k = 4 + i * 4
            func rotation(_ frame: [Float]) -> simd_quatf {
                simd_quatf(vector: SIMD4<Float>(frame[k],frame[k+1],frame[k+2],frame[k+3]))
            }
            let target = simd_slerp(rotation(a), rotation(b), fraction)
            rotations[i] = simd_slerp(previous[i], target, blend)
            bones[i].simdOrientation = rotations[i]
        }
        if motion != .sleep {
            let yaw = simd_quatf(angle: gaze.x * 0.30, axis: [0,1,0])
            let pitch = simd_quatf(angle: gaze.y * 0.17, axis: [1,0,0])
            bones[headIndex].simdOrientation = rotations[headIndex] * yaw * pitch
        }
        for i in eyeIndices {
            bones[i].simdScale.y = openness
            bones[i].simdPosition.z = rest[i].z - (1 - openness) * 0.046
        }
    }
}
