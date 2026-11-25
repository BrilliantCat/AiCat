import ARKit
import AVFoundation
import simd

@MainActor
final class PushupCamera: NSObject, ARSessionDelegate {
    private var session: ARSession?
    private var requestID = UUID()
    private var counter = PushupCounter()
    var onStatus: ((String) -> Void)?
    var onRep: (() -> Void)?
    var onUnavailable: (() -> Void)?

    func start() {
        stop()
        guard ARFaceTrackingConfiguration.isSupported else { onUnavailable?(); return }
        let id = requestID
        Task { @MainActor [weak self] in
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            guard let self, requestID == id else { return }
            guard allowed else { onUnavailable?(); return }
            let capture = ARSession()
            session = capture
            capture.delegate = self
            let config = ARFaceTrackingConfiguration()
            config.isLightEstimationEnabled = false
            capture.run(config)
            onStatus?("Посмотри на iPhone и задержись в верхней точке.")
        }
    }

    func stop() {
        requestID = UUID()
        session?.delegate = nil
        session?.pause()
        session = nil
        counter = PushupCounter()
    }

    func resetCountCycle() { counter = PushupCounter() }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let id = ObjectIdentifier(session)
        let time = frame.timestamp
        let distance: Float? = frame.anchors.compactMap { $0 as? ARFaceAnchor }.first(where: { $0.isTracked }).map {
            let relative = frame.camera.transform.inverse * $0.transform
            return abs(relative.columns.3.z)
        }
        Task { @MainActor [weak self] in
            guard let self, let active = self.session, ObjectIdentifier(active) == id else { return }
            let previous = counter.phase
            let rep = counter.update(distance: distance, at: time)
            if previous != counter.phase {
                switch counter.phase {
                case .calibrating: onStatus?("Вижу тебя не полностью. Посмотри на экран в верхней точке.")
                case .ready: onStatus?("Готов. Опускайся и возвращайся вверх.")
                case .lowered: onStatus?("Вижу нижнюю точку. Поднимайся.")
                }
            }
            if rep { onRep?() }
        }
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        interrupted(ObjectIdentifier(session))
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        interrupted(ObjectIdentifier(session))
    }

    private nonisolated func interrupted(_ id: ObjectIdentifier) {
        Task { @MainActor [weak self] in
            guard let self, let active = self.session, ObjectIdentifier(active) == id else { return }
            onUnavailable?()
        }
    }
}
