import Foundation

/// A single ball in floor coordinates (X, Z). Its motion is independent of the kitten's skeleton.
struct CatBallGame {
    enum Phase { case idle, chasing, batting, rollingAway }
    static let radius: Float = 0.095
    static let runSpeed: Float = 1.38
    private static let paw = SIMD2<Float>(0.163, 0.72)
    private(set) var phase: Phase = .idle
    private(set) var ball = SIMD2<Float>.zero
    private(set) var position = SIMD2<Float>.zero
    private(set) var heading: Float = 0
    private(set) var strideRate: Float = 0
    private(set) var hits = 0
    private var velocity = SIMD2<Float>.zero
    private var speed: Float = 0
    var battingProgress: Float { battingTime / 0.56 }
    private var battingTime: Float = 0
    private var repeats = false
    private var approach = SIMD2<Float>(0, 1)

    private func length(_ offset: SIMD2<Float>) -> Float {
        hypot(offset.x, offset.y)
    }

    private mutating func chooseApproach(to landing: SIMD2<Float>) {
        let delta = landing - position
        if length(delta) > 0.035 { approach = delta / length(delta) }
        let stand = (landing - approach * length(Self.paw)) * CatRoomScenery.kittenScale
        if abs(stand.x) > 1.88 || stand.y < -0.71 || stand.y > 0.99 {
            let inwardStart = landing - SIMD2<Float>(0, 0.11) / CatRoomScenery.kittenScale
            if length(inwardStart) > 0.035 { approach = inwardStart / length(inwardStart) }
        }
    }

    mutating func start(at cat: SIMD2<Float>, facing yaw: Float, target: SIMD2<Float>? = nil, repeats: Bool) {
        position = cat
        heading = yaw
        hits = 0
        speed = 0
        self.repeats = repeats
        ball = Self.onRug(cat + SIMD2<Float>(sin(yaw), cos(yaw)) * 0.73)
        throwBall(towards: target ?? nextTarget)
    }

    mutating func stop() { self = Self() }

    mutating func throwBall(towards target: SIMD2<Float>) {
        let end = Self.onRug(target)
        // With exponential drag the time integral of velocity is the throw distance.
        velocity = (end - ball) * 2.2
        chooseApproach(to: end)
        battingTime = 0
        phase = .chasing
    }

    private var nextTarget: SIMD2<Float> {
        SIMD2<Float>(ball.x >= 0 ? -1.68 : 1.68, hits.isMultiple(of: 2) ? 0.615 : -0.35) / CatRoomScenery.kittenScale
    }

    private static func onRug(_ p: SIMD2<Float>) -> SIMD2<Float> {
        // The playable floor stays the same width when the kitten is resized.
        let scale = CatRoomScenery.kittenScale
        let floor = p * scale
        let target = CatRoomScenery.floorTarget([floor.x, 0, floor.y])
        return SIMD2(target.x, target.z) / scale
    }

    mutating func advance(by dt: Float) {
        guard phase != .idle, dt > 0 else { return }
        let decay = exp(-2.2 * dt)
        ball += velocity * ((1 - decay) / 2.2)
        velocity *= decay
        if phase == .rollingAway {
            if length(velocity) < 0.12 { phase = .idle }
            return
        }
        if phase == .batting {
            let previousTime = battingTime
            battingTime += dt
            if previousTime < 0.46 && battingTime >= 0.46 {
                hits += 1
                velocity = (nextTarget - ball) * 2.2
            }
            if battingTime >= 0.72 {
                if repeats {
                    chooseApproach(to: ball + velocity / 2.2)
                    phase = .chasing
                } else { phase = .rollingAway }
            }
            return
        }

        // Approach from the side of the rug occupied by the cat, leaving space for the reaching paw.
        let yaw = atan2(approach.x, approach.y) - atan2(Self.paw.x, Self.paw.y)
        let stand = ball - approach * length(Self.paw)
        let offset = stand - position
        let distance = length(offset)
        let direction = distance > 0.0001 ? offset / distance : approach
        let aim = distance > 0.13 ? atan2(direction.x, direction.y) : yaw
        let delta = atan2(sin(aim - heading), cos(aim - heading))
        heading += delta * min(1, dt * 8)
        let desiredSpeed = min(Self.runSpeed, sqrt(4.8 * distance)) * max(0, cos(delta))
        speed += max(-3.6 * dt, min(2.5 * dt, desiredSpeed - speed))
        let step = min(speed * dt, distance)
        position += direction * step
        strideRate = step / (dt * Self.runSpeed)
        let paw = position + SIMD2(Self.paw.x * cos(heading) + Self.paw.y * sin(heading),
                                   -Self.paw.x * sin(heading) + Self.paw.y * cos(heading))
        // Account for the ball still coasting while the foreleg extends.
        let contact = ball + velocity * ((1 - exp(Float(-2.2 * 0.46))) / 2.2)
        if distance < 0.05 && length(velocity) < 0.36 && length(contact - paw) < Self.radius {
            speed = 0
            strideRate = 0
            battingTime = 0
            phase = .batting
        }
    }

}
