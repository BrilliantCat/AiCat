// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AiCat",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AiCatCore",
            targets: [
        .binaryTarget(name: "llama", path: "Frameworks/llama.xcframework"),"AiCatCore"]
        )
    ],
    dependencies: [
        // Движок инференса локальных GGUF-моделей под Apple Metal / A17 Pro
        .package(url: "https://github.com/apple/ml-stable-diffusion", exact: "1.1.1")
    ],
    targets: [
        .binaryTarget(name: "llama", path: "Frameworks/llama.xcframework"),
        .target(
            name: "AiCatCore",
            dependencies: [
                "llama",
                .product(name: "StableDiffusion", package: "ml-stable-diffusion")
            ],
            path: "AiCat/Sources"
        )
    ]
)
