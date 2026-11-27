import SceneKit
import UIKit

enum CatClothing {
    struct Fabric {
        let geometry: SCNGeometry
        let weights: SCNGeometrySource
        let indices: SCNGeometrySource
    }

    static let assets: [CatGarment: Fabric] = {
        let files: [CatGarment: String] = [.hoodie: "Hoodie", .vest: "Vest", .trousers: "Trousers"]
        return files.compactMapValues { load($0) }
    }()

    private static func load(_ name: String) -> Fabric? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "cloth", subdirectory: "CatModel"),
              let data = try? Data(contentsOf: url), data.count >= 8 else { return nil }
        let header = data.prefix(8).withUnsafeBytes { bytes in
            (Int(bytes.loadUnaligned(as: UInt32.self)), Int(bytes.loadUnaligned(fromByteOffset: 4, as: UInt32.self)))
        }
        let (n, count) = header
        guard n > 0, n < 100000, count > 0, count.isMultiple(of: 3), data.count == 8 + n*60 + count*4 else { return nil }
        var cursor = 8
        func source(_ semantic: SCNGeometrySource.Semantic, _ components: Int, bytes: Int = 4) -> SCNGeometrySource {
            let stride = components*bytes
            let part = data.subdata(in: cursor..<(cursor+n*stride))
            cursor += n*stride
            return SCNGeometrySource(data: part, semantic: semantic, vectorCount: n, usesFloatComponents: bytes == 4,
                                     componentsPerVector: components, bytesPerComponent: bytes, dataOffset: 0, dataStride: stride)
        }
        let positions = source(.vertex, 3)
        let normals = source(.normal, 3)
        let colors = source(.color, 4)
        let joints = source(.boneIndices, 4, bytes: 1)
        let weights = source(.boneWeights, 4)
        let faces = SCNGeometryElement(data: data.subdata(in: cursor..<data.count), primitiveType: .triangles,
                                       primitiveCount: count/3, bytesPerIndex: 4)
        let geometry = SCNGeometry(sources: [positions, normals, colors], elements: [faces])
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = UIColor.white
        material.isDoubleSided = true
        geometry.materials = [material]
        return Fabric(geometry: geometry, weights: weights, indices: joints)
    }
}
