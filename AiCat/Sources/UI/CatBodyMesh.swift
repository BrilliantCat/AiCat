import Foundation
import SceneKit
import UIKit

/// Positions, weights and bind transforms come from the same authored rest pose as the clips.
enum CatBodyMesh {
    struct Sequence: Decodable {
        let seconds: Float
        let frames: [[Float]]
    }

    struct Clip: Decodable {
        let seconds: Float
        let frames: [[Float]]
        let entry: Sequence?
    }
    struct Description: Decodable {
        let version: Int
        let vertices: Int
        let coatTriangles: Int
        let triangles: Int
        let bones: [String]
        let parents: [Int]
        let origins: [[Float]]
        let clips: [String: Clip]
    }

    struct Asset {
        let description: Description
        let geometry: SCNGeometry
        let weights: SCNGeometrySource
        let indices: SCNGeometrySource
    }

    static let asset: Asset? = load()

    private static func load() -> Asset? {
        let bundle = Bundle.main
        guard let manifest = bundle.url(forResource: "BritishKitten", withExtension: "json", subdirectory: "CatModel"),
              let mesh = bundle.url(forResource: "BritishKitten", withExtension: "mesh", subdirectory: "CatModel"),
              let data = try? Data(contentsOf: mesh, options: .mappedIfSafe),
              let coatURL = bundle.url(forResource: "SilverCoat", withExtension: "png", subdirectory: "CatModel"),
              let texture = UIImage(contentsOfFile: coatURL.path),
              let json = try? Data(contentsOf: manifest),
              let model = try? JSONDecoder().decode(Description.self, from: json),
              model.version == 3, (1...500_000).contains(model.vertices), (1...500_000).contains(model.triangles),
              model.bones.count == model.parents.count, model.bones.count == model.origins.count,
              model.parents.first == -1, model.parents.enumerated().dropFirst().allSatisfy({ $0.element >= 0 && $0.element < $0.offset }),
              model.origins.allSatisfy({ $0.count == 3 }),
              CatMotion.allCases.allSatisfy({ motion in
                  guard let clip = model.clips[motion.rawValue] else { return false }
                  func valid(_ seconds: Float, _ frames: [[Float]]) -> Bool {
                      seconds > 0 && frames.count >= 2 &&
                          frames.allSatisfy { $0.count == 4 + 4 * model.bones.count }
                  }
                  return valid(clip.seconds, clip.frames) &&
                      (clip.entry.map { valid($0.seconds, $0.frames) } ?? true)
              }) else { return nil }
        let stride = 56
        let end = model.vertices * stride
        guard data.count == end + model.triangles * 12,
              (1..<model.triangles).contains(model.coatTriangles) else { return nil }
        func source(_ semantic: SCNGeometrySource.Semantic, _ offset: Int, _ count: Int, bytes: Int = 4) -> SCNGeometrySource {
            SCNGeometrySource(data: data, semantic: semantic, vectorCount: model.vertices,
                              usesFloatComponents: bytes == 4, componentsPerVector: count, bytesPerComponent: bytes,
                              dataOffset: offset, dataStride: stride)
        }
        let coatFaces = model.coatTriangles
        let split = end + coatFaces * 12
        let faces = [SCNGeometryElement(data: data.subdata(in: end..<split), primitiveType: .triangles,
                                        primitiveCount: coatFaces, bytesPerIndex: 4),
                     SCNGeometryElement(data: data.subdata(in: split..<data.count), primitiveType: .triangles,
                                        primitiveCount: model.triangles - coatFaces, bytesPerIndex: 4)]
        // Float colors have the same normalized values in SceneKit and the desktop reviewer.
        // SCNSkinner expects non-interleaved bone weight/index buffers matching vertex count.
        var colors = [Float]()
        colors.reserveCapacity(model.vertices * 4)
        var boneIndices = Data()
        boneIndices.reserveCapacity(model.vertices * 4)
        var boneWeights = Data()
        boneWeights.reserveCapacity(model.vertices * 16)
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            guard let base = bytes.baseAddress else { return }
            for i in 0..<model.vertices {
                let vertex = i * stride
                for channel in 0..<4 { colors.append(Float(bytes[vertex + 24 + channel]) / 255) }
                boneIndices.append((base + vertex + 28).assumingMemoryBound(to: UInt8.self), count: 4)
                boneWeights.append((base + vertex + 32).assumingMemoryBound(to: UInt8.self), count: 16)
            }
        }
        let color = SCNGeometrySource(data: colors.withUnsafeBufferPointer { Data(buffer: $0) }, semantic: .color,
                                      vectorCount: model.vertices, usesFloatComponents: true, componentsPerVector: 4,
                                      bytesPerComponent: 4, dataOffset: 0, dataStride: 16)
        let geometry = SCNGeometry(sources: [source(.vertex, 0, 3), source(.normal, 12, 3), color,
                                             source(.texcoord, 48, 2)], elements: faces)
        let coat = SCNMaterial()
        coat.lightingModel = .lambert
        coat.isDoubleSided = true
        let details = SCNMaterial()
        details.diffuse.contents = UIColor.white
        details.lightingModel = .lambert
        details.isDoubleSided = true
        coat.diffuse.contents = texture
        coat.diffuse.wrapS = .repeat
        coat.diffuse.wrapT = .repeat
        geometry.materials = [coat, details]
        let weights = SCNGeometrySource(data: boneWeights, semantic: .boneWeights, vectorCount: model.vertices,
                                        usesFloatComponents: true, componentsPerVector: 4, bytesPerComponent: 4,
                                        dataOffset: 0, dataStride: 16)
        let indices = SCNGeometrySource(data: boneIndices, semantic: .boneIndices, vectorCount: model.vertices,
                                        usesFloatComponents: false, componentsPerVector: 4, bytesPerComponent: 1,
                                        dataOffset: 0, dataStride: 4)
        return Asset(description: model, geometry: geometry, weights: weights, indices: indices)
    }
}
