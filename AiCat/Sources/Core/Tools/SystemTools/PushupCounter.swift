import Foundation

/// Counts a descent and return to the calibrated starting height.
struct PushupCounter {
    enum Phase { case calibrating, ready, lowered }
    private(set) var phase: Phase = .calibrating
    private var top: Float = 0
    private var stableSince: TimeInterval?
    private var loweredAt: TimeInterval = 0
    private var lastSeen: TimeInterval?

    mutating func update(distance: Float?, at time: TimeInterval) -> Bool {
        if let lastSeen, time <= lastSeen { return false }
        if let lastSeen, time - lastSeen > 0.65 { self = Self() }
        guard let distance, distance.isFinite, (0.08...1.35).contains(distance) else { return false }
        lastSeen = time
        switch phase {
        case .calibrating:
            guard distance >= 0.28 else { stableSince = nil; return false }
            if stableSince == nil || abs(top - distance) > 0.035 {
                stableSince = time
                top = distance
            } else if let stableSince, time - stableSince >= 0.45 {
                phase = .ready
            }
        case .ready:
            let depth = min(0.16, max(0.085, top * 0.23))
            if distance < top - depth {
                phase = .lowered
                loweredAt = time
            }
        case .lowered:
            if distance >= top - 0.045 {
                phase = .ready
                return time - loweredAt >= 0.18
            }
        }
        return false
    }
}
