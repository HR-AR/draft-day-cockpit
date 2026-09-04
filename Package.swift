// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AttendedTabOperator",
    platforms: [.macOS(.v14)],
    products: [.library(name: "AttendedTabOperator", targets: ["AttendedTabOperator"])],
    targets: [
        .target(name: "AttendedTabOperator"),
        .testTarget(name: "AttendedTabOperatorTests", dependencies: ["AttendedTabOperator"]),
    ]
)
