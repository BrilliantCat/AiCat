import SwiftUI
import UIKit

/// The exercise timer controls frames baked from the same skeleton as the interactive room.
struct LessonDemonstration: UIViewRepresentable {
    let motion: CatMotion
    let paused: Bool
    let breath: BreathStep?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(motion: CatMotion, paused: Bool, breath: BreathStep?) {
        self.motion = motion
        self.paused = paused
        self.breath = breath
    }

    func makeUIView(context: Context) -> Player {
        Player()
    }

    func updateUIView(_ player: Player, context: Context) {
        player.show(motion, breath: breath, running: !paused && !reduceMotion && scenePhase == .active)
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

        func show(_ motion: CatMotion, breath: BreathStep?, running: Bool) {
            self.breath = breath
            if current != motion {
                current = motion
                elapsed = 0
                previous = nil
                frameIndex = -1
                contentMode = .scaleAspectFill
                clipsToBounds = true
                if let url = Bundle.main.url(forResource: motion.rawValue, withExtension: "jpg", subdirectory: "LivingRoom/Lessons") {
                    sheet = UIImage(contentsOfFile: url.path)?.cgImage
                }
                duration = Self.durations[motion.rawValue] ?? 2
                display()
            }
            if clock == nil {
                let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
                link.preferredFramesPerSecond = 20
                link.add(to: .main, forMode: .common)
                clock = link
            }
            if !running { previous = nil }
            clock?.isPaused = !running
        }

        @objc private func tick(_ link: CADisplayLink) {
            elapsed += min(0.1, link.timestamp - (previous ?? link.timestamp))
            previous = link.timestamp
            display()
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
