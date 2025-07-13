// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ASimpleCameraKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ASimpleCameraKit",
            targets: ["ASimpleCameraKit"]),
        .library(
            name: "ASimpleCameraKitUI",
            targets: ["ASimpleCameraKitUI"]),
    ],
    targets: [
        .target(
            name: "ASimpleCameraKit",
            path: "Sources/CameraKit",
            exclude: ["UI"]),
            
        .target(
            name: "ASimpleCameraKitUI",
            dependencies: ["ASimpleCameraKit"],
            path: "Sources/CameraKit/UI"),
                
        .testTarget(
            name: "ASimpleCameraKitTests",
            dependencies: ["ASimpleCameraKit"]),
    ]
)
