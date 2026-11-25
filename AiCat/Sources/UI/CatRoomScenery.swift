import Foundation
import SceneKit
import UIKit

/// Baked room surfaces share one node and six materials, with the rug at Y = 0.
enum CatRoomScenery {
    static let kittenScale: Float = 0.5625
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
            mat.emission.contents = UIColor(red: night ? 0.52 : 0.15, green: night ? 0.32 : 0.09, blue: 0.045, alpha: 1)
            return mat
        case "matte": return mat
        default: return nil
        }
        guard let url = resource(file, "jpg"), let image = UIImage(contentsOfFile: url.path) else { return nil }
        mat.diffuse.contents = image
        mat.diffuse.mipFilter = .linear
        return mat
    }

    @discardableResult
    static func install(in scene: SCNScene, hour: Int = Calendar.current.component(.hour, from: Date())) -> Bool {
        let night = !(7..<21).contains(hour)
        guard let desc = resource("SittingRoom", "json"), let mesh = resource("SittingRoom", "mesh"),
              let json = try? Data(contentsOf: desc), let layout = try? JSONDecoder().decode(Layout.self, from: json),
              let bytes = try? Data(contentsOf: mesh, options: .mappedIfSafe),
              (1...200_000).contains(layout.vertices) else { return false }
        let stride = 48
        let end = layout.vertices * stride
        guard end <= bytes.count else { return false }
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
                  let mat = material(for: part.material, night: night) else { return false }
            let start = end + cursor * 4
            cursor += part.count
            elements.append(SCNGeometryElement(data: bytes.subdata(in: start..<(end + cursor * 4)),
                                               primitiveType: .triangles, primitiveCount: part.count / 3, bytesPerIndex: 4))
            materials.append(mat)
        }
        guard !elements.isEmpty, end + cursor * 4 == bytes.count else { return false }
        let geometry = SCNGeometry(sources: [source(.vertex, offset: 0, components: 3),
                                              source(.normal, offset: 12, components: 3),
                                              source(.texcoord, offset: 24, components: 2),
                                              source(.color, offset: 32, components: 4)], elements: elements)
        geometry.materials = materials
        let room = SCNNode(geometry: geometry)
        room.name = "SittingRoom"
        scene.rootNode.addChildNode(room)
        let lamp = SCNNode()
        lamp.light = SCNLight()
        lamp.light?.type = .omni
        lamp.light?.color = UIColor(red: 1, green: 0.77, blue: 0.54, alpha: 1)
        lamp.light?.intensity = night ? 360 : 125
        lamp.light?.attenuationStartDistance = 0.25
        lamp.light?.attenuationEndDistance = 3.0
        lamp.simdPosition = [1.77, 1.65, -2.18]
        scene.rootNode.addChildNode(lamp)
        return true
    }
}
