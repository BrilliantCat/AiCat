import SceneKit
import UIKit

/// Room coordinates use the top of the rug as the floor for the paw targets.
enum CatRoomScenery {
    static func install(in scene: SCNScene) {
        let root = scene.rootNode
        let wood = UIColor(red: 0.43, green: 0.27, blue: 0.19, alpha: 1)
        let walnut = UIColor(red: 0.25, green: 0.15, blue: 0.12, alpha: 1)
        let jade = UIColor(red: 0.27, green: 0.46, blue: 0.43, alpha: 1)
        let brass = UIColor(red: 0.83, green: 0.57, blue: 0.30, alpha: 1)
        let linen = UIColor(red: 0.87, green: 0.70, blue: 0.51, alpha: 1)
        let night = !(7..<23).contains(Calendar.current.component(.hour, from: Date()))
        let sky = night ? UIColor(red: 0.15, green: 0.20, blue: 0.38, alpha: 1)
                        : UIColor(red: 0.58, green: 0.78, blue: 0.82, alpha: 1)

        @discardableResult
        func place(_ mesh: SCNGeometry, _ color: UIColor, _ x: Float, _ y: Float, _ z: Float) -> SCNNode {
            let material = SCNMaterial()
            material.diffuse.contents = color
            mesh.firstMaterial = material
            let node = SCNNode(geometry: mesh)
            node.simdPosition = [x, y, z]
            root.addChildNode(node)
            return node
        }
        @discardableResult
        func box(_ width: CGFloat, _ height: CGFloat, _ depth: CGFloat, _ color: UIColor,
                 _ x: Float, _ y: Float, _ z: Float, bevel: CGFloat = 0.015) -> SCNNode {
            place(SCNBox(width: width, height: height, length: depth, chamferRadius: bevel), color, x, y, z)
        }
        box(12, 9, 0.15, jade, 0, 4, -2.75)
        box(12, 0.15, 0.12, walnut, 0, 0.06, -2.59)
        for plank in -5...7 {
            box(12, 0.14, 0.69, wood, 0, -0.14, Float(plank) * 0.70)
        }
        // A rounded, two-tone flatweave rug.
        box(3.25, 0.055, 2.35, linen, 0, -0.05, 0, bevel: 0.025)
        box(3.05, 0.025, 2.15, jade, 0, -0.014, 0)
        for side: Float in [-1, 1] {
            for stripe in 0..<3 {
                box(0.018, 0.006, 2.03, linen, side * (1.29 + Float(stripe) * 0.06), 0, 0)
            }
        }
        // Recessed, mullioned window and a sill with a row of clothbound books.
        box(2.42, 1.77, 0.11, walnut, -0.76, 2.05, -2.60)
        let pane = box(2.28, 1.63, 0.06, sky, -0.76, 2.05, -2.51)
        pane.geometry?.firstMaterial?.emission.contents = sky.withAlphaComponent(0.28)
        let moon = place(SCNSphere(radius: 0.16), linen, -1.48, 2.53, -2.46)
        moon.simdScale.z = 0.15
        moon.geometry?.firstMaterial?.emission.contents = linen.withAlphaComponent(0.6)
        box(0.055, 1.65, 0.08, walnut, -0.76, 2.05, -2.42)
        box(2.32, 0.052, 0.08, walnut, -0.76, 2.04, -2.42)
        box(2.65, 0.11, 0.42, wood, -0.76, 1.16, -2.45)
        for (i, color) in [brass, jade, linen, walnut].enumerated() {
            let h = 0.22 + CGFloat(i % 3) * 0.06
            box(0.10, h, 0.18, color, -1.77 + Float(i) * 0.11, 1.22 + Float(h / 2), -2.34)
        }
        place(SCNCylinder(radius: 0.27, height: 0.08), walnut, 1.28, -0.015, -1.54)
        place(SCNCylinder(radius: 0.032, height: 1.46), brass, 1.28, 0.74, -1.54)
        let shade = place(SCNCone(topRadius: 0.20, bottomRadius: 0.38, height: 0.41),
                          linen, 1.28, 1.62, -1.54)
        shade.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.4, green: 0.23, blue: 0.09, alpha: 1)
    }
}
