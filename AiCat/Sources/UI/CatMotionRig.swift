import SceneKit
import simd
import UIKit

enum CatMotion: Equatable {
    case idle, walk, purr, play, sleep, eat, groom, think, talk, pushUp, squat, plank, yoga, scan, computer
}

/// Drives the torso and four jointed legs independently. Paw targets are in floor coordinates.
final class CatMotionRig {
    private struct Pose {
        var chest = SIMD3<Float>.zero
        var pitch: Float = 0
        var roll: Float = 0
        var head = SIMD3<Float>.zero
        var frontLeft = SIMD3<Float>(-0.23, 0.095, 0.33)
        var frontRight = SIMD3<Float>(0.23, 0.095, 0.33)
        var hindLeft = SIMD3<Float>(-0.36, 0.10, 0.04)
        var hindRight = SIMD3<Float>(0.36, 0.10, 0.04)

        func blended(to next: Pose, amount: Float) -> Pose {
            func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { a + (b - a) * amount }
            return Pose(chest: mix(chest, next.chest),
                        pitch: pitch + (next.pitch - pitch) * amount,
                        roll: roll + (next.roll - roll) * amount,
                        head: mix(head, next.head),
                        frontLeft: mix(frontLeft, next.frontLeft),
                        frontRight: mix(frontRight, next.frontRight),
                        hindLeft: mix(hindLeft, next.hindLeft),
                        hindRight: mix(hindRight, next.hindRight))
        }
    }

    private struct Leg {
        let upper: SCNNode
        let lower: SCNNode
        let paw: SCNNode

        init(root: SCNNode, fur: SCNMaterial, radius: CGFloat) {
            func segment(_ radius: CGFloat) -> SCNNode {
                let mesh = SCNSphere(radius: radius)
                mesh.firstMaterial = fur
                let node = SCNNode(geometry: mesh)
                root.addChildNode(node)
                return node
            }
            upper = segment(radius)
            lower = segment(radius * 0.76)
            paw = segment(radius * 0.94)
            paw.simdScale = [1, 0.76, 1.32]
        }

        func place(hip: SIMD3<Float>, foot: SIMD3<Float>, bend: SIMD3<Float>) {
            let joint = (hip + foot) * 0.5 + bend
            Self.align(upper, from: hip, to: joint, radius: 0.12)
            Self.align(lower, from: joint, to: foot, radius: 0.09)
            paw.simdPosition = foot
        }

        private static func align(_ node: SCNNode, from a: SIMD3<Float>, to b: SIMD3<Float>, radius: Float) {
            let direction = b - a
            let length = max(simd_length(direction), 0.001)
            node.simdPosition = (a + b) * 0.5
            node.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction / length)
            node.simdScale.y = 0.38 + length / (2 * radius)
        }
    }

    private let torso: SCNNode
    private let head: SCNNode
    private let tail: SCNNode
    private let legs: [Leg]
    private let yarn: SCNNode
    private let bowl: SCNNode
    private let laptop: SCNNode
    private let scanner: SCNNode
    private var current = Pose()
    private var start = Pose()
    private var motion: CatMotion = .idle
    private var elapsed: Float = 0
    private var configured = false
    var gaze = SIMD2<Float>.zero
    private var eyeLine = SIMD2<Float>.zero

    init(cat: SCNNode, torso: SCNNode, head: SCNNode, tail: SCNNode, fur: SCNMaterial) {
        self.torso = torso
        self.head = head
        self.tail = tail
        legs = (0..<4).map { _ in Leg(root: cat, fur: fur, radius: 0.12) }

        func prop(_ geometry: SCNGeometry, color: UIColor, at position: SIMD3<Float>, parent: SCNNode) -> SCNNode {
            geometry.firstMaterial?.diffuse.contents = color
            let node = SCNNode(geometry: geometry)
            node.simdPosition = position
            parent.addChildNode(node)
            return node
        }
        let yarn = prop(SCNSphere(radius: 0.115), color: .systemOrange, at: [0.43, 0.115, 0.64], parent: cat)
        self.yarn = yarn
        for index in 0..<5 {
            let thread = prop(SCNTorus(ringRadius: 0.112, pipeRadius: 0.008), color: .systemRed, at: .zero, parent: yarn)
            thread.simdEulerAngles = [Float(index) * 0.61, 0, 0.45]
        }
        let bowl = prop(SCNTorus(ringRadius: 0.18, pipeRadius: 0.052), color: .systemTeal, at: [0, 0.08, 0.88], parent: cat)
        self.bowl = bowl
        let fish = prop(SCNSphere(radius: 0.095), color: .systemOrange, at: [0, 0.025, 0], parent: bowl)
        fish.simdScale = [1.25, 0.48, 0.85]
        let laptop = prop(SCNBox(width: 0.58, height: 0.032, length: 0.37, chamferRadius: 0.018),
                      color: .darkGray, at: [0, 0.40, 0.67], parent: cat)
        self.laptop = laptop
        let screen = prop(SCNBox(width: 0.58, height: 0.34, length: 0.026, chamferRadius: 0.02),
                          color: .systemIndigo, at: [0, 0.16, 0.17], parent: laptop)
        screen.eulerAngles.x = 0.25
        screen.geometry?.firstMaterial?.emission.contents = UIColor.systemBlue.withAlphaComponent(0.32)
        let scanner = prop(SCNTorus(ringRadius: 0.55, pipeRadius: 0.012), color: .systemMint, at: [0, 0.2, 0], parent: cat)
        self.scanner = scanner
        scanner.geometry?.firstMaterial?.emission.contents = UIColor.systemMint
        set(.idle, reduced: false)
    }

    func set(_ next: CatMotion, reduced: Bool) {
        if !configured || motion != next {
            configured = true
            start = current
            motion = next
            elapsed = 0
            yarn.isHidden = next != .play
            bowl.isHidden = next != .eat
            laptop.isHidden = next != .computer
            scanner.isHidden = next != .scan
        }
        if reduced { render(time: 0.65, blend: 1) }
    }

    func advance(by dt: Float) {
        elapsed += dt
        eyeLine += (gaze - eyeLine) * min(1, dt * 9)
        let u = min(1, elapsed / 0.38)
        render(time: elapsed, blend: u * u * (3 - 2 * u))
    }

    private func render(time: Float, blend: Float) {
        var pose = Pose()
        let breath = sin(time * 2.25)
        pose.chest.y = breath * 0.018
        pose.head.y = sin(time * 1.4) * 0.11
        switch motion {
        case .idle:
            pose.head.z = 0.065 * sin(time * 0.85)
        case .walk:
            let phase = time * 7.5
            let stride: Float = 0.14
            pose.pitch = 0.58
            pose.chest = [0.025 * cos(phase), -0.12 + 0.025 * cos(2 * phase), -0.05]
            pose.head = [-0.43, 0.05 * sin(phase), 0]
            func step(_ base: SIMD3<Float>, phase: Float) -> SIMD3<Float> {
                base + [0, max(0, cos(phase)) * 0.09, stride * sin(phase)]
            }
            pose.frontLeft = step([-0.23, 0.095, 0.54], phase: phase)
            pose.frontRight = step([0.23, 0.095, 0.54], phase: phase + .pi)
            pose.hindLeft = step([-0.30, 0.10, -0.32], phase: phase + .pi)
            pose.hindRight = step([0.30, 0.10, -0.32], phase: phase)
        case .purr:
            let lean = (1 - cos(time * 2.4)) * 0.5
            pose.chest.x = 0.06 * lean
            pose.head = [-0.14, 0.18 * lean, -0.22 * lean]
        case .sleep:
            pose.chest = [0, -0.26 + breath * 0.016, 0]
            pose.pitch = 0.28
            pose.roll = 0.34
            pose.head = [0.22, -0.26, 0.28]
            pose.frontLeft = [-0.14, 0.10, 0.53]
            pose.frontRight = [0.14, 0.10, 0.43]
        case .play:
            let reach = (1 - cos(time * 5.5)) * 0.5
            pose.chest = [0.11 * reach, -0.16 * reach, 0]
            pose.pitch = 0.18 * reach
            pose.head = [0.14, -0.28, -0.11]
            pose.frontRight = [0.24 + reach * 0.12, 0.09 + reach * 0.22, 0.33 + reach * 0.22]
            yarn.simdPosition.x = 0.44 + reach * 0.16
            yarn.simdEulerAngles.z = -reach * 1.35
        case .eat:
            let bite = sin(time * 9)
            pose.chest = [0, -0.23, 0.11]
            pose.pitch = 0.52
            pose.head = [0.29 + 0.07 * bite, 0, 0.045 * bite]
        case .groom:
            let lick = sin(time * 7)
            pose.head = [0.19 + 0.08 * lick, -0.19, 0.13]
            pose.frontLeft = [-0.22, 0.92 + 0.06 * lick, 0.51]
        case .think:
            pose.head = [-0.16, 0.23 + sin(time * 2) * 0.10, -0.17]
            pose.frontRight = [0.24, 0.83, 0.46]
        case .talk:
            pose.head = [0.06 * sin(time * 6), 0.12 * sin(time * 2.5), 0.08 * sin(time * 3)]
            pose.frontRight.y += (1 - cos(time * 3)) * 0.16
        case .computer:
            pose.head = [0.15, 0.14, -0.06]
            pose.frontLeft = [-0.20, 0.46 + 0.061 * sin(time * 13), 0.62]
            pose.frontRight = [0.20, 0.46 - 0.059 * sin(time * 13), 0.62]
        case .scan:
            pose.head = [-0.08, sin(time * 2.8) * 0.56, 0.06]
            scanner.simdPosition.y = 0.25 + (1 - cos(time * 3)) * 0.60
        case .squat:
            let descent = (1 - cos(time * 3.2)) * 0.5
            pose.chest = [0, 0.32 - 0.44 * descent, -0.20 * descent]
            pose.pitch = 0.17 * descent
            pose.head = [-0.12 * descent, 0, 0]
            pose.frontLeft = [-0.30, 0.98 - 0.26 * descent, 0.57]
            pose.frontRight = [0.30, 0.98 - 0.26 * descent, 0.57]
        case .pushUp, .plank, .yoga:
            let drop = motion == .pushUp ? (1 - cos(time * 3.6)) * 0.12 : 0
            let stretch = motion == .yoga ? (1 - cos(time * 2.2)) * 0.22 : 0
            pose.chest = [0, 0.02 - drop - stretch, -0.23]
            pose.pitch = 1.05 + drop * 0.55 + stretch
            pose.head = [-0.67, 0, motion == .yoga ? 0.12 : 0]
            pose.frontLeft = [-0.29, 0.09, 0.51 + stretch]
            pose.frontRight = [0.29, 0.09, 0.51 + stretch]
            pose.hindLeft = [-0.34, 0.1, -0.66]
            pose.hindRight = [0.34, 0.1, -0.66]
        }
        if motion != .sleep {
            pose.head.x += eyeLine.y * 0.30
            pose.head.y += eyeLine.x * 0.56
        }
        current = start.blended(to: pose, amount: blend)
        torso.simdPivot = simd_float4x4(columns: ([1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0.48,0,1]))
        torso.simdPosition = current.chest + [0, 0.48, 0]
        torso.simdEulerAngles = [current.pitch, 0, current.roll]
        head.simdEulerAngles = current.head
        tail.simdEulerAngles = [motion == .sleep ? 0.65 : 0, sin(time * 1.9) * 0.33, motion == .sleep ? -0.77 : 0.18 * breath]

        let shoulders: [SIMD3<Float>] = [[-0.21,0.72,0.22], [0.21,0.72,0.22], [-0.32,0.32,-0.11], [0.32,0.32,-0.11]]
        let feet = [current.frontLeft, current.frontRight, current.hindLeft, current.hindRight]
        for index in legs.indices {
            let hip = torso.simdConvertPosition(shoulders[index], to: torso.parent)
            let side: Float = index.isMultiple(of: 2) ? -1 : 1
            legs[index].place(hip: hip, foot: feet[index], bend: [side * 0.04, 0, index < 2 ? -0.08 : 0.12])
        }
    }
}
