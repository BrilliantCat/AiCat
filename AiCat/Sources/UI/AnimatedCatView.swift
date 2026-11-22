import SwiftUI
import ImageIO

struct AnimatedCatView: UIViewRepresentable {
    let scene: String
    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }
    func updateUIView(_ view: UIImageView, context: Context) {
        guard view.accessibilityIdentifier != scene else { return }
        view.accessibilityIdentifier = scene
        view.stopAnimating()
        view.animationImages = nil
        guard let url = Bundle.main.url(forResource: scene, withExtension: "apng", subdirectory: "AiCat-Animation"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            if let url = Bundle.main.url(forResource: scene, withExtension: "png", subdirectory: "AiCat-Visuals/widget") {
                view.image = UIImage(contentsOfFile: url.path)
            }
            return
        }
        var duration = 0.0
        let frames = (0..<CGImageSourceGetCount(source)).compactMap { index -> UIImage? in
            guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else { return nil }
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let png = properties?[kCGImagePropertyPNGDictionary] as? [CFString: Any]
            duration += max(0.02, png?[kCGImagePropertyAPNGDelayTime] as? Double ?? 0.1)
            return UIImage(cgImage: image)
        }
        view.image = frames.first
        view.animationImages = frames
        view.animationDuration = duration
        view.startAnimating()
    }
    static func dismantleUIView(_ view: UIImageView, coordinator: ()) {
        view.stopAnimating()
        view.animationImages = nil
    }
}
