// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PedidosExpress",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PedidosExpress",
            targets: ["PedidosExpress"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PedidosExpress",
            dependencies: []),
    ]
)
