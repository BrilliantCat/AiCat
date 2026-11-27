import Foundation
import SceneKit
import UIKit

/// Baked room surfaces share one node and six materials, with the rug at Y = 0.
enum CatRoomScenery {
    static let kittenScale: Float = 0.5625
    // Mesh half extents include the border. Leave room for paws and tail when the body turns.
    static let rugX: ClosedRange<Float> = -3.6...3.6
    static let rugZ: ClosedRange<Float> = -1.58...3.72

    static func floorTarget(_ p: SIMD3<Float>) -> SIMD3<Float> {
        [min(rugX.upperBound - 0.90, max(rugX.lowerBound + 0.90, p.x)), 0,
         min(rugZ.upperBound - 1.32, max(rugZ.lowerBound + 0.53, p.z))]
    }

    // All sofa, window and lamp vertices are baked about this anchor in make_living_room.py.
    static func furnishing(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> {
        [1.23*x, 1.23*y, -2.75 + 1.23*(z + 2.75)]
    }

    static func sofaSeat(tappedX x: Float) -> SIMD3<Float> {
        // Both spots are on a seat cushion, just forward of the loose throw pillows.
        furnishing(x < -0.80 * 1.23 ? -1.42 : -0.12, 0.528, -2.22)
    }

    private struct Layout: Decodable {
        struct Part: Decodable {
            let material: String
            let first: Int
            let count: Int
        }
        let vertices: Int
        let parts: [Part]
    }

    private static func resource(_ name: String, _ ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "LivingRoom")
    }

    private static func material(for key: String, night: Bool) -> SCNMaterial? {
        let mat = SCNMaterial()
        mat.lightingModel = .lambert
        mat.isDoubleSided = true
        mat.diffuse.contents = UIColor.white
        let file: String
        switch key {
        case "rug": file = "Kilim"
        case "linen": file = "Linen"
        case "oak": file = "Oak"
        case "window":
            file = night ? "StreetNight" : "StreetDay"
            mat.lightingModel = .constant
        case "shade":
            mat.name = key
            mat.emission.contents = UIColor(red: night ? 0.52 : 0.15, green: night ? 0.32 : 0.09, blue: 0.045, alpha: 1)
            return mat
        case "matte": return mat
        default: return nil
        }
        guard let url = resource(file, "jpg"), let image = UIImage(contentsOfFile: url.path) else { return nil }
        mat.name = key
        if key == "window" {
            var flip = SCNMatrix4MakeScale(1, -1, 1)
            flip.m42 = 1
            mat.diffuse.contentsTransform = flip
        }
        mat.diffuse.contents = image
        mat.diffuse.mipFilter = .linear
        return mat
    }

    @discardableResult
    static func toggleLamp(in scene: SCNScene?) -> Bool? {
        guard let root = scene?.rootNode, let lamp = root.childNode(withName: "FloorLamp", recursively: false)?.light,
              let shade = root.childNode(withName: "SittingRoom", recursively: false)?.geometry?.material(named: "shade") else { return nil }
        let on = lamp.intensity == 0
        lamp.intensity = on ? 420 : 0
        shade.emission.contents = on ? UIColor(red: 0.65, green: 0.44, blue: 0.14, alpha: 1) : UIColor.black
        return on
    }

    // All rooms share immutable mesh buffers. Only the lamp shade is mutable per scene.
    private static let roomMesh = loadGeometry()
    private static let nightWindow = material(for: "window", night: true)

    private static func loadGeometry() -> SCNGeometry? {
        guard let desc = resource("SittingRoom", "json"), let mesh = resource("SittingRoom", "mesh"),
              let json = try? Data(contentsOf: desc), let layout = try? JSONDecoder().decode(Layout.self, from: json),
              let bytes = try? Data(contentsOf: mesh, options: .mappedIfSafe),
              (1...200_000).contains(layout.vertices) else { return nil }
        let stride = 48
        let end = layout.vertices * stride
        guard end <= bytes.count else { return nil }
        func source(_ semantic: SCNGeometrySource.Semantic, offset: Int, components: Int) -> SCNGeometrySource {
            SCNGeometrySource(data: bytes, semantic: semantic, vectorCount: layout.vertices,
                              usesFloatComponents: true, componentsPerVector: components, bytesPerComponent: 4,
                              dataOffset: offset, dataStride: stride)
        }
        var elements: [SCNGeometryElement] = []
        var materials: [SCNMaterial] = []
        var cursor = 0
        for part in layout.parts {
            guard part.first == cursor, part.count > 0, part.count.isMultiple(of: 3),
                  part.count <= (bytes.count - end) / 4 - cursor,
                  let mat = material(for: part.material, night: false) else { return nil }
            let start = end + cursor * 4
            cursor += part.count
            elements.append(SCNGeometryElement(data: bytes.subdata(in: start..<(end + cursor * 4)),
                                               primitiveType: .triangles, primitiveCount: part.count / 3, bytesPerIndex: 4))
            materials.append(mat)
        }
        guard !elements.isEmpty, end + cursor * 4 == bytes.count else { return nil }
        let geometry = SCNGeometry(sources: [source(.vertex, offset: 0, components: 3),
                                              source(.normal, offset: 12, components: 3),
                                              source(.texcoord, offset: 24, components: 2),
                                              source(.color, offset: 32, components: 4)], elements: elements)
        geometry.materials = materials
        return geometry
    }

    @discardableResult
    static func install(in scene: SCNScene, hour: Int = Calendar.current.component(.hour, from: Date())) -> Bool {
        let night = !(7..<21).contains(hour)
        guard let template = roomMesh, let geometry = template.copy() as? SCNGeometry else { return false }
        var materials = template.materials
        for i in materials.indices {
            if night && materials[i].name == "window" {
                guard let nightWindow else { return false }
                materials[i] = nightWindow
            } else if materials[i].name == "shade" {
                guard let shade = material(for: "shade", night: night) else { return false }
                materials[i] = shade
            }
        }
        geometry.materials = materials
        let room = SCNNode(geometry: geometry)
        room.name = "SittingRoom"
        scene.rootNode.addChildNode(room)
        let lamp = SCNNode()
        lamp.name = "FloorLamp"
        lamp.light = SCNLight()
        lamp.light?.type = .omni
        lamp.light?.color = UIColor(red: 1, green: 0.77, blue: 0.54, alpha: 1)
        lamp.light?.intensity = night ? 360 : 125
        lamp.light?.attenuationStartDistance = 0.25
        lamp.light?.attenuationEndDistance = 3.0
        lamp.simdPosition = furnishing(1.44, 1.55, -2.35)
        scene.rootNode.addChildNode(lamp)
        return true
    }
}
