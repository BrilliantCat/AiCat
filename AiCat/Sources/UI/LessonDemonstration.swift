import SwiftUI
import UIKit
import SceneKit

/// The active lesson drives one player. Baked frames are available for devices with rendering issues.
struct LessonDemonstration: UIViewRepresentable {
    let motion: CatMotion
    let paused: Bool
    let breath: BreathStep?
    let useSheets: Bool
    let visible: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(motion: CatMotion, paused: Bool, breath: BreathStep?, useSheets: Bool, visible: Bool) {
        self.motion = motion
        self.paused = paused
        self.useSheets = useSheets
        self.visible = visible
        self.breath = breath
    }

    func makeUIView(context: Context) -> Player {
        let player = Player()
        player.layer.cornerRadius = 24
        player.layer.cornerCurve = .continuous
        player.clipsToBounds = true
        return player
    }

    func updateUIView(_ player: Player, context: Context) {
        player.show(motion, breath: breath, useSheets: useSheets, running: visible && !paused && !reduceMotion && scenePhase == .active)
    }

    static func dismantleUIView(_ player: Player, coordinator: ()) {
        player.clock?.invalidate()
    }

    final class Player: UIImageView {
        override var intrinsicContentSize: CGSize { .zero }
        var clock: CADisplayLink?
        private var sheet: CGImage?
        private var current: CatMotion?
        private var frameIndex = -1
        private var duration = 1.0
        private var elapsed = 0.0
        private var previous: CFTimeInterval?
        private var breath: BreathStep?

        private var stage: SCNView?
        private var rig: CatMotionRig?
        private var lastSheetMode: Bool?
        private var useFallback = false
        private let phaseLabel = UILabel()
        private var probeAt: TimeInterval = .infinity

        private func prepareStage() {
            let scene = SCNScene()
            let actor = SCNNode()
            guard let skeleton = CatMotionRig(cat: actor, includeClothes: false), CatRoomScenery.install(in: scene) else { return }
            let scale = CatRoomScenery.kittenScale
            actor.simdScale = SIMD3(repeating: scale)
            actor.eulerAngles.y = -0.94
            scene.rootNode.addChildNode(actor)
            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera?.projectionDirection = .horizontal
            camera.camera?.fieldOfView = 37
            camera.simdPosition = SIMD3<Float>(0, 1.34, 4.05) * scale
            camera.look(at: SCNVector3(0, 0.63 * scale, 0))
            scene.rootNode.addChildNode(camera)
            let key = SCNNode()
            key.light = SCNLight()
            key.light?.type = .directional
            key.light?.intensity = 900
            key.position = SCNVector3(-2,4,4)
            key.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(key)
            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .ambient
            fill.light?.intensity = 380
            scene.rootNode.addChildNode(fill)
            let view = SCNView(frame: bounds)
            view.autoresizingMask = [.flexibleWidth,.flexibleHeight]
            view.scene = scene
            view.pointOfView = camera
            view.backgroundColor = .darkGray
            view.isOpaque = true
            view.preferredFramesPerSecond = 30
            view.antialiasingMode = .none
            insertSubview(view, at: 0)
            rig = skeleton
            stage = view
        }

        func show(_ motion: CatMotion, breath: BreathStep?, useSheets: Bool, running: Bool) {
            self.breath = breath
            if phaseLabel.superview == nil {
                phaseLabel.textColor = .white
                phaseLabel.backgroundColor = UIColor.black.withAlphaComponent(0.68)
                phaseLabel.font = .preferredFont(forTextStyle: .subheadline)
                phaseLabel.adjustsFontForContentSizeCategory = true
                phaseLabel.layer.cornerRadius = 10
                phaseLabel.clipsToBounds = true
                phaseLabel.textAlignment = .center
                phaseLabel.translatesAutoresizingMaskIntoConstraints = false
                addSubview(phaseLabel)
                NSLayoutConstraint.activate([
                    phaseLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                    phaseLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
                    phaseLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -16)
                ])
            }
            let sheets = useSheets || useFallback
            if current != motion || lastSheetMode != sheets {
                lastSheetMode = sheets
                if !sheets && stage == nil { prepareStage() }
                if sheets { stage?.removeFromSuperview(); stage = nil; rig = nil }
                let live = stage != nil
                probeAt = live ? 0.45 : .infinity
                rig?.set(motion, reduced: true)
                sheet = nil
                image = nil
                current = motion
                elapsed = 0
                previous = nil
                frameIndex = -1
                contentMode = .scaleAspectFit
                backgroundColor = UIColor(red: 0.15, green: 0.14, blue: 0.13, alpha: 1)
                clipsToBounds = true
                if !live, let url = Bundle.main.url(forResource: motion.rawValue, withExtension: "jpg", subdirectory: "LivingRoom/Lessons") {
                    sheet = UIImage(contentsOfFile: url.path)?.cgImage
                }
                duration = Self.durations[motion.rawValue] ?? 2
                display()
            }
            updatePhaseLabel()
            if clock == nil {
                let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
                link.preferredFramesPerSecond = 30
                link.add(to: .main, forMode: .common)
                clock = link
            }
            if !running { previous = nil }
            clock?.isPaused = !running
            stage?.isPlaying = running
        }

        @objc private func tick(_ link: CADisplayLink) {
            let dt = min(0.1, link.timestamp - (previous ?? link.timestamp))
            elapsed += dt
            previous = link.timestamp
            if let rig, let stage {
                rig.advance(by: Float(dt), breathPhase: breath?.phase(at: Date()))
                if elapsed >= probeAt && bounds.width > 1 && bounds.height > 1 {
                    probeAt = .infinity
                    if Self.magenta(stage.snapshot()), let current {
                        useFallback = true
                        show(current, breath: breath, useSheets: true, running: true)
                    }
                }
            } else { display() }
            updatePhaseLabel()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let camera = stage?.pointOfView?.camera, bounds.height > 0 else { return }
            let aspect = Double(bounds.width / bounds.height)
            let horizontal = max(tan(37.0 * .pi / 360), 0.23 * aspect)
            camera.fieldOfView = CGFloat(2 * atan(horizontal) * 180 / .pi)
        }

        private func updatePhaseLabel() {
            guard let current else { return }
            let progress = elapsed.truncatingRemainder(dividingBy: duration) / duration
            let cue: String
            switch current {
            case .pushUp, .squat:
                switch progress {
                case 0.06..<0.44: cue = "Опускаемся"
                case 0.44..<0.56: cue = "Задержка внизу"
                case 0.56..<0.94: cue = "Поднимаемся"
                default: cue = "Исходная поза"
                }
            case .breath: cue = breath.map { $0.inhale ? "Вдох" : "Выдох" } ?? (progress < 0.5 ? "Вдох" : "Выдох")
            case .plank: cue = "Держим упор"
            default: cue = ""
            }
            phaseLabel.isHidden = cue.isEmpty
            let caption = "  " + cue + "  "
            if phaseLabel.text != caption { phaseLabel.text = caption }
        }

        private static func magenta(_ image: UIImage) -> Bool {
            guard let cg = image.cgImage else { return false }
            var pixels = [UInt8](repeating: 0, count: 64*4)
            return pixels.withUnsafeMutableBytes { storage in
                guard let ctx = CGContext(data: storage.baseAddress, width: 8, height: 8, bitsPerComponent: 8,
                                          bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.draw(cg, in: CGRect(x: 0,y: 0,width: 8,height: 8))
                let p = storage.bindMemory(to: UInt8.self)
                return stride(from: 0,to: p.count,by: 4).filter { p[$0] > 210 && p[$0+1] < 45 && p[$0+2] > 195 }.count > 58
            }
        }

        private func display() {
            guard let sheet else { return }
            let phase = breath.map { Double($0.phase(at: Date())) } ?? elapsed.truncatingRemainder(dividingBy: duration) / duration
            let i = min(19, max(0, Int(phase * 20)))
            guard i != frameIndex else { return }
            frameIndex = i
            let w = sheet.width / 5, h = sheet.height / 4
            if let cell = sheet.cropping(to: CGRect(x: CGFloat((i % 5) * w), y: CGFloat((i / 5) * h), width: CGFloat(w), height: CGFloat(h))) {
                image = UIImage(cgImage: cell)
            }
        }
        private static let durations: [String: Double] = ["walk": 0.8, "squat": 2.2, "pushUp": 2.2, "plank": 3.2, "yoga": 3.6, "stretch": 4.2, "curl": 4.8, "breath": 4.0, "shoulders": 2.8]
    }
}
