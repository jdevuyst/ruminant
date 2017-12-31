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
    ],
    
    targets: [
        .target(
            name: "ruminant",
            path: ".",
            sources: ["Sources"]),
        
        .testTarget(
            name: "ruminantTests",
            dependencies: ["ruminant"],
            path: "./Tests",
            sources: ["ruminantTests"]),
        ]
)
