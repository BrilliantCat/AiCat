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
            targets: ["AiCatCore"]
        )
    ],
    dependencies: [
        // Движок инференса локальных GGUF-моделей под Apple Metal / A17 Pro
        .package(url: "https://github.com/ggerganov/llama.cpp", branch: "master")
    ],
    targets: [
        .target(
            name: "AiCatCore",
            dependencies: [
                .product(name: "llama", package: "llama.cpp")
            ],
            path: "AiCat/Sources"
        )
    ]
)
