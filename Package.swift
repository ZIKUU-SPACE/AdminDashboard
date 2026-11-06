
 // ~/workspace/AdminDashboard/Package.swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AdminDashboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AdminDashboard",
            targets: ["AdminDashboard"]
        ),
        .executable(
            name: "AdminDashboardService",
            targets: ["AdminDashboardService"]
        ),
        .library(
            name: "AdminDashboardShared",
            targets: ["AdminDashboardShared"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-framework"),
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            exact: "2.15.0"
        ),
        .package(
            url: "https://github.com/swift-server/async-http-client.git",
            exact: "1.37.0"
        ),
    ],
    targets: [
        .target(
            name: "AdminDashboardShared"
        ),
        .executableTarget(
            name: "AdminDashboard",
            dependencies: [
                "AdminDashboardShared",
                .product(
                    name: "ZIKUU",
                    package: "swift-framework"
                ),
            ]
        ),
        .executableTarget(
            name: "AdminDashboardService",
            dependencies: [
                "AdminDashboardShared",
                .product(
                    name: "Hummingbird",
                    package: "hummingbird"
                ),
                .product(
                    name: "AsyncHTTPClient",
                    package: "async-http-client"
                ),
            ]
        ),
    ]
)
