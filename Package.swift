// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "ruminant",
    
    products: [
        .library(
            name: "ruminant",
            targets: ["ruminant"]),
    ],
    
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.8.1")
    ],
    
    targets: [
        .target(
            name: "ruminant",
            path: ".",
            sources: ["Sources"]),
        
        .testTarget(
            name: "ruminantTests",
            dependencies: ["ruminant", "SwiftCheck"],
            path: "./Tests",
            sources: ["ruminantTests"]),
        ]
)
