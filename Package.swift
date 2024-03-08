// swift-tools-version:5.7

import PackageDescription

let package = Package(
    name: "swift-graphql",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        // SwiftGraphQL
        .library(name: "SwiftGraphQL", targets: ["SwiftGraphQL"]),
        .library(name: "SwiftGraphQLClient", targets: ["SwiftGraphQLClient"]),
        // Utilities
        .library(name: "GraphQL", targets: ["GraphQL"]),
        .library(name: "GraphQLWebSocket", targets: ["GraphQLWebSocket"]),

        // Plugin
        .plugin(name: "SwiftGraphQLPlugin", targets: ["SwiftGraphQLPlugin"])
    ],
    dependencies: [
        // .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/JohnSundell/Files", from: "4.0.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.0.0"),
    ],
    targets: [
        // Spec
        .target(name: "GraphQL", dependencies: [], path: "Sources/GraphQL"),
        .target(
            name: "GraphQLWebSocket",
            dependencies: [
                "GraphQL",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
                .product(name: "NIOConcurrencyHelpers", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
            ],
            path: "Sources/GraphQLWebSocket",
            exclude: ["README.md"]
        ),

        // SwiftGraphQL

        .target(
            name: "SwiftGraphQL",
            dependencies: [
                "GraphQL",
            ],
            path: "Sources/SwiftGraphQL"
        ),
        .target(
            name: "SwiftGraphQLClient",
            dependencies: [
                "GraphQL",
                "GraphQLWebSocket",
                .product(name: "Logging", package: "swift-log"),
                "SwiftGraphQL",
            ],
            path: "Sources/SwiftGraphQLClient"
        ),

        // Tests

        .testTarget(
            name: "SwiftGraphQLTests",
            dependencies: [
                "Files",
                "GraphQL",
                "GraphQLWebSocket",
                "SwiftGraphQL",
                "SwiftGraphQLClient",
            ],
            path: "Tests"
        ),

        // Plugin
        .plugin(
            name: "SwiftGraphQLPlugin",
            capability: .command(
                intent: .custom(
                    verb: "swift-graphql",
                    description: ""
                ),
                permissions: [.writeToPackageDirectory(reason: "")]
            )
        )
    ]
)


//#if os(Linux)
package.targets.append(
    .target(name: "Combine", dependencies: [
        .product(name: "RxSwift", package: "RxSwift"),
    ])
)
package.dependencies.append(
    .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.0.0")
)
//#endif
